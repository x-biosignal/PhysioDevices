# Withings Health Mate reader (Withings ScanWatch, Sleep, BPM, body scales).
#
# The Withings "Download my data" export is a folder of per-type CSVs
# (raw_hr_hr.csv, spo2.csv / raw_spo2_*.csv, bp.csv, weight.csv, ...). Column
# names vary a little by locale/type, so the reader keys off the filename for the
# modality and detects the time/value columns by name heuristics, reusing
# .hc_col()/.iso_time(). Sleep is exported as nightly aggregates (durations), not
# epoch-level stages, so it is not expanded to stage intervals here.

#' Read a Withings Health Mate export
#'
#' Parses a Withings "Download my data" export directory into tidy per-modality
#' tables: `heart_rate` (`bpm`), `spo2`, `blood_pressure` (`systolic`,
#' `diastolic`) and `weight` (`kg`). The modality is taken from the filename and
#' the time/value columns are detected heuristically. Covers Withings ScanWatch /
#' Sleep / BPM / Body devices.
#'
#' @param path Directory of the export (searched recursively), or a file / vector
#'   of files.
#' @param tz Time zone for the parsed timestamps (default `"UTC"`).
#' @return A `withings` object: a list with any of `heart_rate`, `spo2`,
#'   `blood_pressure`, `weight`, plus `path`/`tz`. `spo2` feeds
#'   `PhysioWearable::spo2Metrics()`.
#' @seealso [readOura()], [readFitbit()]
#' @references Withings Health Mate data export.
#' @export
#' @examples
#' \dontrun{
#' w <- readWithings("withings_export")
#' PhysioWearable::spo2Metrics(w$spo2$value, time = w$spo2$time)
#' }
readWithings <- function(path, tz = "UTC") {
  if (length(path) > 1L) files <- path[file.exists(path)]
  else if (dir.exists(path)) files <- list.files(path, pattern = "\\.csv$", recursive = TRUE,
                                                 full.names = TRUE, ignore.case = TRUE)
  else if (file.exists(path)) files <- path
  else stop("Withings path not found: ", path, call. = FALSE)
  if (!length(files)) stop("No .csv files found under: ", path, call. = FALSE)

  rd <- function(f) tryCatch(utils::read.csv(f, stringsAsFactors = FALSE, check.names = FALSE),
                             error = function(e) {
                               warning("Skipping unreadable Withings CSV '", basename(f), "'.",
                                       call. = FALSE); NULL })
  timecol <- function(d) {
    s <- .hc_col(d, "^start|^date|^time|created|timestamp")
    if (is.null(s)) s <- .hc_col(d, "time|date")
    s
  }
  acc <- list()
  for (f in files) {
    bn <- tolower(basename(f))
    # blood pressure and SpO2 filenames also contain "hr"/"raw", so test them first.
    type <- if (grepl("bp|blood.?press|systol", bn)) "blood_pressure"
            else if (grepl("spo2|sp02|oxygen", bn)) "spo2"
            else if (grepl("weight|body", bn)) "weight"
            else if (grepl("hr|heart|pulse", bn)) "heart_rate"
            else next
    d <- rd(f); if (is.null(d) || !nrow(d)) next
    tc <- timecol(d)
    if (is.null(tc)) { warning("No time column in '", basename(f), "'.", call. = FALSE); next }
    tm <- .iso_time(tc, tz)
    df <- switch(type,
      blood_pressure = {
        sys <- .hc_col(d, "systol"); dia <- .hc_col(d, "diastol")
        if (is.null(sys) && is.null(dia)) { warning("No BP columns in '", basename(f), "'.",
                                                    call. = FALSE); next }
        data.frame(time = tm,
                   systolic  = suppressWarnings(as.numeric(.orElse(sys, NA))),
                   diastolic = suppressWarnings(as.numeric(.orElse(dia, NA))),
                   stringsAsFactors = FALSE)
      },
      weight = {
        v <- .hc_col(d, "weight|value|kg")
        if (is.null(v)) { warning("No weight column in '", basename(f), "'.", call. = FALSE); next }
        data.frame(time = tm, kg = suppressWarnings(as.numeric(v)), stringsAsFactors = FALSE)
      },
      spo2 = {
        v <- .hc_col(d, "spo2|oxygen|value|percent")
        if (is.null(v)) { warning("No SpO2 column in '", basename(f), "'.", call. = FALSE); next }
        data.frame(time = tm, value = suppressWarnings(as.numeric(v)), stringsAsFactors = FALSE)
      },
      heart_rate = {
        v <- .hc_col(d, "heart|bpm|pulse|value")
        if (is.null(v)) { warning("No heart-rate column in '", basename(f), "'.", call. = FALSE); next }
        data.frame(time = tm, bpm = suppressWarnings(as.numeric(v)), stringsAsFactors = FALSE)
      })
    acc[[type]] <- c(acc[[type]], list(df))
  }
  if (!length(acc)) {
    stop("No recognised Withings CSVs under: ", path,
         " (expected raw_hr_hr.csv / spo2.csv / bp.csv / weight.csv).", call. = FALSE)
  }
  out <- lapply(acc, function(parts) {
    x <- do.call(rbind, parts); x[order(x$time), , drop = FALSE]
  })
  structure(c(out, list(path = path, tz = tz)), class = "withings")
}

#' @export
print.withings <- function(x, ...) {
  cat("<withings>", paste(setdiff(names(x), c("path", "tz")), collapse = ", "), "\n")
  invisible(x)
}
