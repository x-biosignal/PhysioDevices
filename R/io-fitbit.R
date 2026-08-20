# Fitbit archive reader (also covers Google Pixel Watch, whose health data is
# stored in Fitbit).
#
# Fitbit's account data export (Settings -> "Export Your Account Archive") and
# the Fitbit slice of Google Takeout are a directory of many small per-day files:
# `heart_rate-YYYY-MM-DD.json`, `steps-YYYY-MM-DD.json`, `sleep-YYYY-MM-DD.json`,
# `resting_heart_rate-YYYY-MM-DD.json`, and SpO2 as daily JSON or minute CSV.
# The Fitbit Web-API / research extraction (e.g. the PMData dataset) instead
# writes one aggregated file per modality -- `heart_rate.json`, `steps.json`,
# `sleep.json` -- with the same record structure but no per-day date suffix.
# `readFitbit()` discovers both layouts by filename, parses the (nested) JSON, and
# returns tidy per-modality series plus sleep-stage intervals. Exact filenames
# and structure vary a little by archive version, so the reader keys off filename
# patterns and skips files it cannot parse (with a warning) rather than failing.

.orElse <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

.need_jsonlite <- function() {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The 'jsonlite' package is required to read Fitbit exports. ",
         "Install it with: install.packages('jsonlite')", call. = FALSE)
  }
}

# Fitbit uses two timestamp styles: US "MM/DD/YY HH:MM:SS" (intraday) and ISO
# "YYYY-MM-DDTHH:MM:SS.sss" (sleep); some fields are date-only. Try each in turn.
.fitbit_time <- function(x, tz = "UTC") {
  s <- sub("T", " ", sub("\\.[0-9]+", "", as.character(x)))
  t <- as.POSIXct(s, format = "%Y-%m-%d %H:%M:%S", tz = tz)
  na <- is.na(t); if (any(na)) t[na] <- as.POSIXct(s[na], format = "%m/%d/%y %H:%M:%S", tz = tz)
  na <- is.na(t); if (any(na)) t[na] <- as.POSIXct(s[na], format = "%Y-%m-%d", tz = tz)
  t
}

# Intraday {dateTime, value} files. `value_field` pulls a nested field (e.g. the
# "bpm" inside heart_rate's value object); NULL treats value as a scalar.
.fitbit_intraday <- function(files, tz, value_field = NULL) {
  parts <- lapply(files, function(f) tryCatch({
    j <- jsonlite::fromJSON(f, simplifyVector = TRUE)
    if (!is.data.frame(j) || !"dateTime" %in% names(j)) return(NULL)
    val <- j$value
    if (!is.null(value_field) && is.data.frame(val)) val <- val[[value_field]]
    data.frame(time = .fitbit_time(j$dateTime, tz),
               value = suppressWarnings(as.numeric(unlist(val))),
               stringsAsFactors = FALSE)
  }, error = function(e) {
    warning("Skipping unreadable Fitbit file '", basename(f), "': ",
            conditionMessage(e), call. = FALSE); NULL
  }))
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (!length(parts)) return(NULL)
  df <- do.call(rbind, parts)
  df[order(df$time), ]
}

.fitbit_spo2 <- function(files, tz) {
  parts <- lapply(files, function(f) tryCatch({
    if (grepl("\\.csv$", f, ignore.case = TRUE)) {
      d <- utils::read.csv(f, stringsAsFactors = FALSE, check.names = FALSE)
      tcol <- grep("time|date", names(d), ignore.case = TRUE)[1]
      vcol <- grep("value|spo2|oxygen|sp02", names(d), ignore.case = TRUE)[1]
      if (is.na(tcol) || is.na(vcol)) return(NULL)
      data.frame(time = .fitbit_time(d[[tcol]], tz),
                 value = suppressWarnings(as.numeric(d[[vcol]])))
    } else {
      j <- jsonlite::fromJSON(f, simplifyVector = TRUE)
      if (!is.data.frame(j) || !"dateTime" %in% names(j)) return(NULL)
      val <- j$value
      v <- if (is.data.frame(val)) val[[grep("avg|value", names(val), ignore.case = TRUE)[1]]]
           else suppressWarnings(as.numeric(val))
      data.frame(time = .fitbit_time(j$dateTime, tz), value = suppressWarnings(as.numeric(v)))
    }
  }, error = function(e) NULL))
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (!length(parts)) return(NULL)
  df <- do.call(rbind, parts)
  df[order(df$time), ]
}

.fitbit_sleep <- function(files, tz) {
  stages <- list(); summ <- list()
  for (f in files) {
    j <- tryCatch(jsonlite::fromJSON(f, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(j)) next
    for (log in j) {
      lvl <- log$levels$data
      if (length(lvl)) {
        dt  <- .fitbit_time(vapply(lvl, function(d) as.character(d$dateTime), ""), tz)
        sec <- vapply(lvl, function(d) as.numeric(d$seconds), numeric(1))
        stg <- vapply(lvl, function(d) as.character(d$level), "")
        stages[[length(stages) + 1L]] <- data.frame(
          start = dt, end = dt + sec, stage = stg,
          log_id = .orElse(log$logId, NA), stringsAsFactors = FALSE)
      }
      summ[[length(summ) + 1L]] <- data.frame(
        log_id = .orElse(log$logId, NA),
        start = .fitbit_time(.orElse(log$startTime, NA), tz),
        end = .fitbit_time(.orElse(log$endTime, NA), tz),
        efficiency = as.numeric(.orElse(log$efficiency, NA)),
        minutes_asleep = as.numeric(.orElse(log$minutesAsleep, NA)),
        minutes_awake = as.numeric(.orElse(log$minutesAwake, NA)),
        time_in_bed = as.numeric(.orElse(log$timeInBed, NA)),
        stringsAsFactors = FALSE)
    }
  }
  list(stages = if (length(stages)) do.call(rbind, stages) else NULL,
       summary = if (length(summ)) do.call(rbind, summ) else NULL)
}

#' Read a Fitbit / Google Pixel data archive
#'
#' Parses a Fitbit account-export (or Google Takeout) directory into tidy
#' per-modality series. Files are discovered by name and both layouts are
#' handled: the account archive's per-day files (`heart_rate-YYYY-MM-DD.json`,
#' `steps-*`, `sleep-*`, ...) and the Web-API / research extraction's aggregated
#' single files (`heart_rate.json`, `steps.json`, `sleep.json`; e.g. the PMData
#' dataset). Modalities: heart rate (`bpm`), steps, `resting_heart_rate`, SpO2
#' (`spo2*`/`*oxygen*`, JSON or minute CSV), and sleep (Fitbit's own
#' `wake`/`light`/`deep`/`rem` stages). Google Pixel Watch health data is stored
#' in Fitbit, so the same reader covers it.
#'
#' @param path Directory of the extracted archive (searched recursively), or a
#'   file / vector of files.
#' @param what Optional character vector restricting which modalities to read
#'   (any of `"heart_rate"`, `"steps"`, `"spo2"`, `"resting_heart_rate"`,
#'   `"sleep"`); `NULL` (default) reads all that are found.
#' @param tz Time zone for the parsed timestamps (default `"UTC"`).
#' @return A `fitbit` object: a list with any of `heart_rate`, `steps`, `spo2`,
#'   `resting_heart_rate` (data frames of `time`, `value`), `sleep` (stage
#'   intervals `start`, `end`, `stage`, `log_id`) and `sleep_summary` (Fitbit's
#'   per-log `efficiency`, `minutes_asleep`, `time_in_bed`, ...), plus `path`/`tz`.
#'   The `sleep` stages feed `PhysioWearable::summarizeSleepStages()`; `spo2` feeds
#'   `PhysioWearable::spo2Metrics()`.
#' @seealso [readAppleHealth()], [fitbitSeries()]
#' @references Fitbit Web API data types; Fitbit account data export.
#' @export
#' @examples
#' \dontrun{
#' fb <- readFitbit("Takeout/Fitbit", tz = "Asia/Tokyo")
#' fb
#' PhysioWearable::spo2Metrics(fb$spo2$value, time = fb$spo2$time)
#' }
readFitbit <- function(path, what = NULL, tz = "UTC") {
  .need_jsonlite()
  if (length(path) > 1L) {
    files <- path[file.exists(path)]
  } else if (dir.exists(path)) {
    files <- list.files(path, pattern = "\\.(json|csv)$", recursive = TRUE,
                        full.names = TRUE, ignore.case = TRUE)
  } else if (file.exists(path)) {
    files <- path
  } else {
    stop("Fitbit path not found: ", path, call. = FALSE)
  }
  if (!length(files)) stop("No .json/.csv files found under: ", path, call. = FALSE)

  bn <- tolower(basename(files))
  pick <- function(pat) files[grepl(pat, bn)]
  want <- function(m) is.null(what) || m %in% what

  # Patterns match both the per-day archive (`heart_rate-2019-01-01.json`) and the
  # aggregated Web-API export (`heart_rate.json`); the `^` keeps `heart_rate-*`
  # from also matching `resting_heart_rate-*`, and `[-.]` keeps `sleep[-.]` from
  # matching `sleep_score.csv`.
  out <- list()
  if (want("heart_rate")) {
    hr <- pick("^heart_rate[-.]")
    if (length(hr)) { d <- .fitbit_intraday(hr, tz, value_field = "bpm")
                      if (!is.null(d)) { names(d)[2] <- "bpm"; out$heart_rate <- d } }
  }
  if (want("steps")) {
    s <- pick("^steps[-.]")
    if (length(s)) out$steps <- .fitbit_intraday(s, tz)
  }
  if (want("spo2")) {
    o <- pick("spo2|oxygen|sp02")
    if (length(o)) out$spo2 <- .fitbit_spo2(o, tz)
  }
  if (want("resting_heart_rate")) {
    r <- pick("resting_heart_rate")
    if (length(r)) out$resting_heart_rate <- .fitbit_intraday(r, tz, value_field = "value")
  }
  if (want("sleep")) {
    sl <- pick("^sleep[-.]")
    if (length(sl)) { sp <- .fitbit_sleep(sl, tz); out$sleep <- sp$stages
                      out$sleep_summary <- sp$summary }
  }

  if (!length(out)) {
    stop("No recognised Fitbit modality files under: ", path,
         " (expected heart_rate-*, steps-*, sleep-*, spo2*, resting_heart_rate-*).",
         call. = FALSE)
  }
  structure(c(out, list(path = path, tz = tz)), class = "fitbit")
}

#' @export
print.fitbit <- function(x, ...) {
  mods <- setdiff(names(x), c("path", "tz", "sleep_summary"))
  cat("<fitbit>", length(mods), "modalities:", paste(mods, collapse = ", "), "\n")
  for (m in mods) {
    d <- x[[m]]
    if (is.data.frame(d)) {
      tcol <- if ("time" %in% names(d)) d$time else d$start
      cat(sprintf("  %-18s %d rows  %s -> %s\n", m, nrow(d),
                  format(min(tcol, na.rm = TRUE)), format(max(tcol, na.rm = TRUE))))
    }
  }
  invisible(x)
}

#' Extract one modality from a Fitbit archive
#'
#' @param x A `fitbit` object from [readFitbit()].
#' @param modality One of the modality names present in `x` (e.g. `"heart_rate"`,
#'   `"spo2"`, `"sleep"`).
#' @return The modality's data frame.
#' @seealso [readFitbit()]
#' @export
fitbitSeries <- function(x, modality) {
  stopifnot(inherits(x, "fitbit"))
  if (is.null(x[[modality]])) {
    stop("No modality '", modality, "'. Present: ",
         paste(setdiff(names(x), c("path", "tz")), collapse = ", "), call. = FALSE)
  }
  x[[modality]]
}
