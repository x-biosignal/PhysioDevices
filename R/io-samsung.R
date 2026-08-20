# Samsung Health reader (Galaxy Watch and Samsung Health app).
#
# Samsung Health exports a folder of CSVs named `com.samsung.(s)health.<type>...csv`,
# each with a one-line metadata comment above the real header (so read with
# skip = 1). This reads the columnar modalities -- heart rate, blood oxygen,
# steps -- by filename + column heuristics. Sleep-stage detail is a separate,
# more complex Samsung schema and is not parsed here. Uses .hc_col()/.iso_time().

# Samsung timestamps are "yyyy-mm-dd HH:MM:SS(.sss)" or epoch milliseconds.
.samsung_time <- function(x, tz) {
  s <- as.character(x)
  ms <- grepl("^[0-9]{12,}$", s)                 # epoch millis
  out <- .iso_time(s, tz)
  if (any(ms)) out[ms] <- as.POSIXct(suppressWarnings(as.numeric(s[ms])) / 1000,
                                     origin = "1970-01-01", tz = tz)
  out
}

#' Read a Samsung Health export
#'
#' Parses a Samsung Health CSV export directory into tidy per-modality series --
#' heart rate, blood oxygen (SpO2) and steps -- detecting the record type from
#' the `com.samsung...` filename and the time/value columns heuristically (each
#' file has a one-line metadata comment above its header). Galaxy Watch health
#' data is stored in Samsung Health, so this covers it.
#'
#' @param path Directory of the export (searched recursively), or a file / vector
#'   of files.
#' @param tz Time zone for the parsed timestamps (default `"UTC"`).
#' @return A `samsung_health` object: a list with any of `heart_rate` (`bpm`),
#'   `spo2`, `steps` (`time`, `value`), plus `path`/`tz`. `spo2` feeds
#'   `PhysioWearable::spo2Metrics()`.
#' @seealso [readHealthConnect()], [readFitbit()]
#' @references Samsung Health data export.
#' @export
#' @examples
#' \dontrun{
#' sh <- readSamsungHealth("samsunghealth_export")
#' }
readSamsungHealth <- function(path, tz = "UTC") {
  if (length(path) > 1L) files <- path[file.exists(path)]
  else if (dir.exists(path)) files <- list.files(path, pattern = "\\.csv$", recursive = TRUE,
                                                 full.names = TRUE, ignore.case = TRUE)
  else if (file.exists(path)) files <- path
  else stop("Samsung Health path not found: ", path, call. = FALSE)
  if (!length(files)) stop("No .csv files found under: ", path, call. = FALSE)

  acc <- list()
  for (f in files) {
    bn <- tolower(basename(f))
    type <- if (grepl("heart_rate", bn)) "heart_rate"
            else if (grepl("oxygen", bn)) "spo2"
            else if (grepl("step_count|step_daily|\\.step", bn)) "steps"
            else next
    d <- tryCatch(utils::read.csv(f, skip = 1, stringsAsFactors = FALSE, check.names = FALSE),
                  error = function(e) NULL)
    if (is.null(d) || !nrow(d)) next
    tcol <- .hc_col(d, "start_time|create_time|day_time|^time|date")
    if (is.null(tcol)) tcol <- .hc_col(d, "time|date")
    if (is.null(tcol)) { warning("No time column in '", basename(f), "'.", call. = FALSE); next }
    val <- switch(type,
      heart_rate = .hc_col(d, "heart_rate|\\bhr\\b|value"),
      spo2       = .hc_col(d, "spo2|oxygen|value"),
      steps      = .hc_col(d, "count|value"))
    if (is.null(val)) { warning("No value column in '", basename(f), "'.", call. = FALSE); next }
    df <- data.frame(time = .samsung_time(tcol, tz),
                     value = suppressWarnings(as.numeric(val)), stringsAsFactors = FALSE)
    if (type == "heart_rate") names(df)[names(df) == "value"] <- "bpm"
    acc[[type]] <- c(acc[[type]], list(df))
  }
  if (!length(acc)) {
    stop("No recognised Samsung Health CSVs under: ", path,
         " (expected com.samsung...heart_rate/oxygen_saturation/step_count).", call. = FALSE)
  }
  out <- lapply(acc, function(parts) {
    x <- do.call(rbind, parts); x[order(x$time), , drop = FALSE]
  })
  structure(c(out, list(path = path, tz = tz)), class = "samsung_health")
}

#' @export
print.samsung_health <- function(x, ...) {
  cat("<samsung_health>", paste(setdiff(names(x), c("path", "tz")), collapse = ", "), "\n")
  invisible(x)
}
