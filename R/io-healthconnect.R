# Android Health Connect reader.
#
# Health Connect (the current Android on-device health store) has no single
# official export file; the practical path is a per-record-type CSV export (one
# CSV per type: `HeartRate.csv`, `Steps.csv`, `OxygenSaturation.csv`,
# `SleepSession.csv`, `RespiratoryRate.csv`, ...), produced by Health Connect's
# own export or third-party exporter apps. Column names vary by exporter, so
# `readHealthConnect()` keys off the filename for the record type and detects the
# time/value columns by name heuristics. Uses `.iso_time()` from io-googlefit.R.
#
# The heuristics target the documented schema: the androidx Health Connect record
# field names (heart rate `beatsPerMinute`, `Steps.count`, `percentage`, `rate`,
# HRV `heartRateVariabilityMillis`, `SleepSessionRecord.StageType`) and real
# exporter layouts such as MyDataHelps (PascalCase `Time`/`BeatsPerMinute`/
# `StartTime`/`EndTime`/`Stage`, a leading `HealthConnectRecordKey`, `Metadata*`
# columns, ISO-8601 with ms+offset or a UTC `Z`). No public real export exists, so
# conformance is pinned by tests/testthat/test-io-healthconnect-schema.R.

.hc_normtype <- function(name) {
  n <- gsub("[^a-z0-9]", "", tolower(name))
  if (grepl("variability", n)) "hrv"        # before "heartrate": HRV != heart rate
  else if (grepl("heartrate", n)) "heart_rate"
  else if (grepl("step", n)) "steps"
  else if (grepl("oxygen|spo2|sp02", n)) "spo2"
  else if (grepl("sleep", n)) "sleep"
  else if (grepl("respirat", n)) "respiratory_rate"
  else NA_character_                          # unknown -> caller skips with a warning
}

.hc_col <- function(d, pat) {
  i <- grep(pat, names(d), ignore.case = TRUE)[1]
  if (is.na(i)) NULL else d[[i]]
}

#' Read an Android Health Connect CSV export
#'
#' Parses a directory of Health Connect record-type CSVs (one file per type) into
#' tidy per-modality series. Recognises `HeartRate`, `Steps`, `OxygenSaturation`,
#' `RespiratoryRate` and `SleepSession` (its stages) by filename; the time and
#' value columns are found by name heuristics, so the common exporter layouts
#' work without configuration.
#'
#' @param path Directory of the CSV export (searched recursively), or a file /
#'   vector of files.
#' @param tz Time zone for parsed timestamps (default `"UTC"`).
#' @return A `health_connect` object: a list with any of `heart_rate`, `steps`,
#'   `spo2`, `respiratory_rate` (`time`, `value`), and `sleep` (stage intervals
#'   `start`, `end`, `stage`), plus `path`/`tz`. `spo2` feeds
#'   `PhysioWearable::spo2Metrics()`, `sleep` feeds
#'   `PhysioWearable::summarizeSleepStages()`.
#' @seealso [readGoogleFit()], [readFitbit()]
#' @references Android Health Connect data types and export.
#' @export
#' @examples
#' \dontrun{
#' hc <- readHealthConnect("health_connect_export", tz = "Asia/Tokyo")
#' hc
#' PhysioWearable::spo2Metrics(hc$spo2$value, time = hc$spo2$time)
#' }
readHealthConnect <- function(path, tz = "UTC") {
  if (length(path) > 1L) {
    files <- path[file.exists(path)]
  } else if (dir.exists(path)) {
    files <- list.files(path, pattern = "\\.csv$", recursive = TRUE,
                        full.names = TRUE, ignore.case = TRUE)
  } else if (file.exists(path)) {
    files <- path
  } else stop("Health Connect path not found: ", path, call. = FALSE)
  if (!length(files)) stop("No .csv files found under: ", path, call. = FALSE)

  acc <- list()                       # per-type list of frames -> one rbind at the end
  for (f in files) {
    d <- tryCatch(utils::read.csv(f, stringsAsFactors = FALSE, check.names = FALSE),
                  error = function(e) {
                    warning("Skipping unreadable Health Connect CSV '", basename(f), "': ",
                            conditionMessage(e), call. = FALSE); NULL
                  })
    if (is.null(d) || !nrow(d)) next
    type <- .hc_normtype(sub("\\.csv$", "", basename(f), ignore.case = TRUE))
    if (is.na(type)) {
      warning("Skipping unrecognised Health Connect file '", basename(f),
              "' (unknown record type).", call. = FALSE); next
    }

    # Sample time: prefer a start/time column; the fallback avoids an interval-end column.
    start <- .hc_col(d, "^start|^time$|instant|^date")
    if (is.null(start)) {
      cand <- grep("time|date", names(d), ignore.case = TRUE, value = TRUE)
      cand <- cand[!grepl("end|finish|stop", cand, ignore.case = TRUE)]
      if (length(cand)) start <- d[[cand[1]]]
    }
    if (is.null(start)) {
      warning("No time column in '", basename(f), "'; skipped.", call. = FALSE); next
    }
    st <- .iso_time(start, tz)

    if (type == "sleep") {
      stg <- .hc_col(d, "stage|sleeplevel|^level$")     # not bare "type" (matches sessionType)
      if (is.null(stg)) {
        warning("No stage column in '", basename(f), "'; skipped.", call. = FALSE); next
      }
      end <- .hc_col(d, "end|finish|stop")
      if (is.null(end)) {
        warning("No end column in '", basename(f),
                "'; sleep stages will have zero duration.", call. = FALSE)
      }
      df <- data.frame(
        start = st, end = if (!is.null(end)) .iso_time(end, tz) else st,
        stage = tolower(sub("^STAGE_TYPE_", "", as.character(stg), ignore.case = TRUE)),
        stringsAsFactors = FALSE)
    } else {
      val <- switch(type,
        heart_rate = .hc_col(d, "beatsperminute|bpm|value"),
        # canonical androidx field is heartRateVariabilityMillis, not "rmssd"
        hrv        = .hc_col(d, "rmssd|variabilit|value"),
        steps      = .hc_col(d, "count|value"),
        spo2       = .hc_col(d, "percentage|percent|value"),
        respiratory_rate = .hc_col(d, "rate|value"),
        .hc_col(d, "value"))
      if (is.null(val)) {
        warning("No value column in '", basename(f), "'; skipped.", call. = FALSE); next
      }
      df <- data.frame(time = st, value = suppressWarnings(as.numeric(val)),
                       stringsAsFactors = FALSE)
      if (type == "heart_rate") names(df)[names(df) == "value"] <- "bpm"
    }
    acc[[type]] <- c(acc[[type]], list(df))
  }

  if (!length(acc)) {
    stop("No recognised Health Connect record CSVs under: ", path,
         " (expected HeartRate/Steps/OxygenSaturation/SleepSession/RespiratoryRate).",
         call. = FALSE)
  }
  out <- lapply(acc, function(parts) {
    df <- do.call(rbind, parts)
    df[order(if ("time" %in% names(df)) df$time else df$start), , drop = FALSE]
  })
  structure(c(out, list(path = path, tz = tz)), class = "health_connect")
}

#' @export
print.health_connect <- function(x, ...) {
  mods <- setdiff(names(x), c("path", "tz"))
  cat("<health_connect>", length(mods), "record types:", paste(mods, collapse = ", "), "\n")
  for (m in mods) if (is.data.frame(x[[m]])) cat(sprintf("  %-16s %d rows\n", m, nrow(x[[m]])))
  invisible(x)
}
