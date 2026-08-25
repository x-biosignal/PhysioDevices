# Actiwatch AWD reader (clinical actigraphy).
#
# Parse an AWD header date ("01-May-2023" or "01.05.2023") + time ("23:00")
# WITHOUT locale dependence (month abbreviations are matched explicitly, then an
# ISO string is built and parsed with the locale-neutral "%Y-%m-%d").
.awd_start <- function(dline, tline, tz) {
  d <- trimws(dline); tt <- trimws(tline)
  mon <- c(jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6,
           jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12)
  iso <- NA_character_
  m <- regmatches(d, regexec("^([0-9]{1,2})[-. /]([A-Za-z]{3,})[-. /]([0-9]{2,4})$", d))[[1]]
  if (length(m) == 4L && !is.null(mon[[tolower(substr(m[3], 1, 3))]])) {
    yr <- as.integer(m[4]); if (yr < 100L) yr <- 2000L + yr
    iso <- sprintf("%04d-%02d-%02d", yr, mon[[tolower(substr(m[3], 1, 3))]], as.integer(m[2]))
  } else {
    m2 <- regmatches(d, regexec("^([0-9]{1,2})[-. /]([0-9]{1,2})[-. /]([0-9]{2,4})$", d))[[1]]
    if (length(m2) == 4L) {
      yr <- as.integer(m2[4]); if (yr < 100L) yr <- 2000L + yr
      iso <- sprintf("%04d-%02d-%02d", yr, as.integer(m2[2]), as.integer(m2[1]))
    }
  }
  if (is.na(iso)) return(as.POSIXct(NA))
  if (grepl("^[0-9]{1,2}:[0-9]{2}$", tt)) tt <- paste0(tt, ":00")
  suppressWarnings(as.POSIXct(paste(iso, tt), format = "%Y-%m-%d %H:%M:%S", tz = tz))
}

# The Actiwatch/Actiware `.awd` export is a simple text file: a short header
# (subject, start date, start time, and a few metadata lines) followed by one
# activity count per line (optionally with a light/marker second column). The
# epoch length is not reliably encoded in the header across firmware versions, so
# it is a parameter. The returned per-epoch activity counts feed
# `PhysioWearable::coleKripke()` / `summarizeSleep()`.

#' Read an Actiwatch AWD actigraphy file
#'
#' Parses a Philips/Respironics Actiwatch `.awd` file into per-epoch activity
#' counts with timestamps. The start date/time is read from the header; the
#' activity counts are the longest run of numeric lines (the data block).
#'
#' @param path Path to a `.awd` file.
#' @param epoch Epoch length in seconds (default 60). The `.awd` header does not
#'   reliably carry it, so set it to your recording's epoch.
#' @param tz Time zone for the timestamps (default `"UTC"`).
#' @return A data frame with `time` (`POSIXct`) and `activity` (counts), with the
#'   epoch length in `attr(, "epoch_sec")`. Feeds
#'   `PhysioWearable::coleKripke()` (which expects 1-minute epochs).
#' @seealso [readGT3X()], [readGENEActiv()]
#' @references Philips Respironics Actiwatch / Actiware AWD format.
#' @export
#' @examples
#' \dontrun{
#' aw <- readActiwatch("subject.awd", epoch = 60)
#' sw <- PhysioWearable::coleKripke(aw$activity)
#' }
readActiwatch <- function(path, epoch = 60, tz = "UTC") {
  if (!is.character(path) || length(path) != 1L || !nzchar(path) || !file.exists(path)) {
    stop("Actiwatch .awd file not found: ", path, call. = FALSE)
  }
  if (!is.numeric(epoch) || length(epoch) != 1L || !is.finite(epoch) || epoch <= 0) {
    stop("`epoch` must be a single positive number (seconds).", call. = FALSE)
  }
  lines <- readLines(path, warn = FALSE)

  # start datetime from the classic header lines 2 (date) and 3 (time)
  start <- if (length(lines) >= 3L) .awd_start(lines[2], lines[3], tz) else as.POSIXct(NA)
  if (is.na(start)) {
    warning("Could not parse the Actiwatch start date/time; using an epoch-0 origin.",
            call. = FALSE)
    start <- as.POSIXct(0, origin = "1970-01-01", tz = tz)
  }

  # activity counts: first token per line; take the longest consecutive numeric run
  first_num <- suppressWarnings(as.numeric(sub("[,;[:space:]].*$", "", trimws(lines))))
  is_num <- !is.na(first_num)
  r <- rle(is_num)
  if (!any(r$values)) stop("No activity-count data found in: ", path, call. = FALSE)
  ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1L
  runs <- which(r$values)
  best <- runs[which.max(r$lengths[runs])]
  counts <- first_num[starts[best]:ends[best]]

  df <- data.frame(time = start + (seq_along(counts) - 1L) * epoch, activity = counts)
  attr(df, "epoch_sec") <- epoch
  attr(df, "source_file") <- basename(path)
  df
}
