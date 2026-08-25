# Google Fit (Google Takeout) reader.
#
# Google Takeout's "Fit" export is heterogeneous: granular per-type JSON under
# "All Data" (`derived_com.google.<type>.*.json`, values with nanosecond epoch
# timestamps), daily summary CSVs under "Daily activity metrics", and per-session
# TCX. `readGoogleFit()` parses the granular JSON (heart rate, steps) and the
# daily CSVs. NB: Google is retiring the Fit APIs in favour of Health Connect
# (see [readHealthConnect()]); Takeout export remains available meanwhile.

# ISO-8601-ish time -> POSIXct, OFFSET-AWARE. Shared by the Google Fit and
# Health Connect readers. Handles a trailing "Z" (UTC) and numeric offsets
# ("+09:00"/"-0800") by parsing them as absolute instants (%z); a value with no
# offset is interpreted as wall-clock in `tz`. Fractional seconds are dropped.
.iso_time <- function(x, tz = "UTC") {
  x <- as.character(x)
  # normalise: Z -> +0000, "+09:00" -> "+0900", drop fractional seconds, T -> space
  norm <- sub("Z$", "+0000", x)
  norm <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", norm)
  norm <- sub("\\.[0-9]+", "", sub("T", " ", norm))
  out <- as.POSIXct(rep(NA_real_, length(norm)), origin = "1970-01-01", tz = tz)
  off <- grepl("[+-][0-9]{4}$", norm)
  if (any(off)) {                       # explicit offset -> absolute instant
    out[off] <- as.POSIXct(norm[off], format = "%Y-%m-%d %H:%M:%S%z", tz = tz)
  }
  if (any(!off)) {                      # naive -> wall-clock in tz
    s <- norm[!off]
    t <- as.POSIXct(s, format = "%Y-%m-%d %H:%M:%S", tz = tz)
    na <- is.na(t); if (any(na)) t[na] <- as.POSIXct(s[na], format = "%Y-%m-%d", tz = tz)
    out[!off] <- t
  }
  out
}

# Nanosecond epoch -> POSIXct. Takes the seconds digits from a canonical digit
# string (avoids the >2^53 precision loss of as.numeric on a 19-digit value); if
# a value arrives as an unquoted JSON number (scientific notation), divide by 1e9.
.gfit_nanos_time <- function(nanos, tz = "UTC") {
  s <- as.character(nanos)
  secs <- rep(NA_real_, length(s))
  dig <- grepl("^[0-9]+$", s)
  if (any(dig)) {
    secs[dig] <- suppressWarnings(as.numeric(substr(s[dig], 1L, pmax(1L, nchar(s[dig]) - 9L))))
  }
  sci <- !dig & grepl("[0-9]", s)                 # e.g. "1.68e+18" from an unquoted int64
  if (any(sci)) secs[sci] <- suppressWarnings(as.numeric(s[sci])) / 1e9
  as.POSIXct(secs, origin = "1970-01-01", tz = tz)
}

.gfit_read_points <- function(file, tz) {
  j <- tryCatch(jsonlite::fromJSON(file, simplifyVector = FALSE),
                error = function(e) {
                  warning("Skipping unreadable Google Fit file '", basename(file), "': ",
                          conditionMessage(e), call. = FALSE); NULL
                })
  if (is.null(j) || is.null(j[["Data Points"]]) || !length(j[["Data Points"]])) return(NULL)
  pts <- j[["Data Points"]]
  time <- .gfit_nanos_time(vapply(pts, function(p) as.character(.orElse(p$startTimeNanos, NA)), ""), tz)
  value <- vapply(pts, function(p) {
    fv <- p$fitValue
    if (is.null(fv) || !length(fv)) return(NA_real_)   # a point can carry an empty fitValue
    v <- fv[[1]]$value
    as.numeric(.orElse(v$fpVal, .orElse(v$intVal, NA)))[1]
  }, numeric(1))
  data.frame(time = time, value = value)[order(time), ]
}

.gfit_read_daily <- function(files, tz) {
  parts <- lapply(files, function(f) tryCatch({
    d <- utils::read.csv(f, stringsAsFactors = FALSE, check.names = FALSE)
    nm <- names(d)
    col <- function(pat) { i <- grep(pat, nm, ignore.case = TRUE)[1]; if (is.na(i)) NA else d[[i]] }
    date <- col("^date")
    data.frame(
      date = if (!is.null(date)) as.Date(as.character(date)) else NA,
      steps = suppressWarnings(as.numeric(col("step"))),
      calories_kcal = suppressWarnings(as.numeric(col("calor"))),
      distance_m = suppressWarnings(as.numeric(col("distance"))),
      hr_avg = suppressWarnings(as.numeric(col("average heart|avg.*heart"))),
      hr_max = suppressWarnings(as.numeric(col("max heart"))),
      hr_min = suppressWarnings(as.numeric(col("min heart"))),
      stringsAsFactors = FALSE)
  }, error = function(e) {
    warning("Skipping unreadable Google Fit daily CSV '", basename(f), "': ",
            conditionMessage(e), call. = FALSE); NULL
  }))
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (!length(parts)) return(NULL)
  do.call(rbind, parts)
}

#' Read a Google Fit (Google Takeout) export
#'
#' Parses the "Fit" folder of a Google Takeout archive. From "All Data" it reads
#' the granular per-type JSON points -- heart rate (`heart_rate.bpm`) and steps
#' (`step_count.delta`) -- decoding their nanosecond timestamps; from "Daily
#' activity metrics" it reads the daily-summary CSVs (steps, calories, distance,
#' average/max/min heart rate).
#'
#' @param path Directory of the extracted Takeout "Fit" folder (searched
#'   recursively), or a file / vector of files.
#' @param what Optional restriction, any of `"heart_rate"`, `"steps"`, `"daily"`.
#' @param tz Time zone for parsed timestamps (default `"UTC"`).
#' @return A `google_fit` object: a list with any of `heart_rate`, `steps`
#'   (`time`, `value`) and `daily` (per-day summary), plus `path`/`tz`.
#' @seealso [readHealthConnect()], [readFitbit()]
#' @references Google Takeout "Fit" export; Google Fit data types.
#' @export
#' @examples
#' \dontrun{
#' gf <- readGoogleFit("Takeout/Fit", tz = "Asia/Tokyo")
#' gf$heart_rate
#' }
readGoogleFit <- function(path, what = NULL, tz = "UTC") {
  .need_jsonlite()
  if (length(path) > 1L) {
    files <- path[file.exists(path)]
  } else if (dir.exists(path)) {
    files <- list.files(path, pattern = "\\.(json|csv)$", recursive = TRUE,
                        full.names = TRUE, ignore.case = TRUE)
  } else if (file.exists(path)) {
    files <- path
  } else stop("Google Fit path not found: ", path, call. = FALSE)
  if (!length(files)) stop("No .json/.csv files found under: ", path, call. = FALSE)

  bn <- tolower(basename(files))
  want <- function(m) is.null(what) || m %in% what
  out <- list()

  if (want("heart_rate")) {
    hr <- files[grepl("heart_rate\\.bpm", bn)]
    parts <- lapply(hr, .gfit_read_points, tz = tz)
    parts <- parts[!vapply(parts, is.null, logical(1))]
    if (length(parts)) {
      d <- do.call(rbind, parts)
      d <- d[order(d$time), ]                       # re-sort across source files
      names(d)[names(d) == "value"] <- "bpm"        # match readFitbit's column name
      out$heart_rate <- d
    }
  }
  if (want("steps")) {
    st <- files[grepl("step_count", bn)]
    parts <- lapply(st, .gfit_read_points, tz = tz)
    parts <- parts[!vapply(parts, is.null, logical(1))]
    if (length(parts)) { d <- do.call(rbind, parts); out$steps <- d[order(d$time), ] }
  }
  if (want("daily")) {
    # "Daily activity metrics" is the folder name, so match the full path.
    dc <- files[grepl("daily.*(metric|activity)", tolower(files)) & grepl("\\.csv$", bn)]
    if (length(dc)) out$daily <- .gfit_read_daily(dc, tz)
  }

  if (!length(out)) {
    stop("No recognised Google Fit data under: ", path,
         " (expected 'All Data' derived_*heart_rate*/step_count JSON or a Daily activity metrics CSV).",
         call. = FALSE)
  }
  structure(c(out, list(path = path, tz = tz)), class = "google_fit")
}

#' @export
print.google_fit <- function(x, ...) {
  mods <- setdiff(names(x), c("path", "tz"))
  cat("<google_fit>", length(mods), "modalities:", paste(mods, collapse = ", "), "\n")
  for (m in mods) if (is.data.frame(x[[m]])) cat(sprintf("  %-12s %d rows\n", m, nrow(x[[m]])))
  invisible(x)
}
