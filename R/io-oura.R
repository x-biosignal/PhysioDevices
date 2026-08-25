# Oura Ring reader.
#
# Oura's sleep JSON comes in two API shapes and `readOura()` handles both:
#   - API v2 (`/v2/usercollection/sleep`): {data:[...]}, phases in
#     `sleep_phase_5_min`, HR/HRV as nested `heart_rate`/`hrv` {interval, items}.
#   - API v1 (`/v1/sleep`): {sleep:[...]}, phases in `hypnogram_5min`, HR/HRV as
#     flat `hr_5min`/`rmssd_5min` arrays (0 = no reading).
# Both encode the 5-minute phase string the same way (1=deep, 2=light, 3=REM,
# 4=awake). `readOura()` expands these into stage intervals + tidy HR/HRV series
# that feed `PhysioWearable::summarizeSleepStages()` and the HRV functions. Uses
# jsonlite and .orElse()/.iso_time() from the sibling readers.

.oura_hypno_map <- c("1" = "deep", "2" = "light", "3" = "rem", "4" = "awake")

# a numeric vector from a possibly-null-containing JSON items list (keeps length)
.oura_items <- function(items) {
  vapply(items, function(x) if (is.null(x)) NA_real_ else suppressWarnings(as.numeric(x)),
         numeric(1))
}

# a single numeric (NA if the field is absent/null/empty) -- a missing summary
# field must not collapse a summary column to length 0 and break data.frame().
.num1 <- function(x) {
  x <- suppressWarnings(as.numeric(unlist(x)))
  if (length(x)) x[1] else NA_real_
}

#' Read an Oura Ring export
#'
#' Parses an Oura sleep export/JSON (API v2 `sleep` collection, or the older API
#' v1 `sleep`) into tidy per-night data: sleep-stage intervals (from the 5-minute
#' phase string), the 5-minute heart-rate and HRV (RMSSD) series, and Oura's own
#' sleep summary. Both API versions are recognised.
#'
#' @param path Path to the Oura sleep JSON (a v2 object with a `data` array, a v1
#'   object with a `sleep` array, or a bare array of sleep periods).
#' @param tz Time zone for the parsed timestamps (default `"UTC"`).
#' @return An `oura` object: a list with `sleep` (stage intervals `start`, `end`,
#'   `stage`, `day`), `sleep_summary` (per-day `efficiency`,
#'   `total_sleep_min`, `time_in_bed_min`), `heart_rate` (`time`, `bpm`) and
#'   `hrv` (`time`, `rmssd`), plus `path`/`tz`. The `sleep` stages feed
#'   `PhysioWearable::summarizeSleepStages()`.
#' @seealso [readFitbit()], [readHealthConnect()]
#' @references Oura API v2 sleep data.
#' @export
#' @examples
#' \dontrun{
#' ou <- readOura("oura_sleep.json", tz = "Asia/Tokyo")
#' PhysioWearable::summarizeSleepStages(ou$sleep,
#'   asleep_levels = c("light", "deep", "rem"))
#' }
readOura <- function(path, tz = "UTC") {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("The 'jsonlite' package is required to read Oura exports. ",
         "Install it with: install.packages('jsonlite')", call. = FALSE)
  }
  if (!is.character(path) || length(path) != 1L || !nzchar(path) || !file.exists(path)) {
    stop("Oura export not found: ", path, call. = FALSE)
  }
  j <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  # Record wrapper differs by API version: v2 is {data:[...]}, v1 is {sleep:[...]};
  # also accept a bare array or a single sleep object.
  recs <- if (!is.null(j$data)) j$data
          else if (!is.null(j$sleep)) j$sleep
          else if (is.null(names(j))) j
          else list(j)

  stages <- list(); summ <- list(); hr <- list(); hrv <- list()
  for (r in recs) {
    # only sleep-shaped records (skip unrelated JSON objects)
    if (is.null(r$bedtime_start) && is.null(r$hypnogram_5min) &&
        is.null(r$sleep_phase_5_min) && is.null(r$efficiency) &&
        is.null(r$total_sleep_duration)) next
    day <- .orElse(.orElse(r$day, r$summary_date), NA)
    bs <- .iso_time(.orElse(r$bedtime_start, NA), tz)
    # Sleep phases: v1 hypnogram_5min or v2 sleep_phase_5_min (same 1-4 encoding).
    hyp <- .orElse(r$hypnogram_5min, r$sleep_phase_5_min)
    if (!is.null(hyp) && nzchar(hyp) && !is.na(bs)) {
      ch <- strsplit(as.character(hyp), "")[[1]]
      st <- bs + (seq_along(ch) - 1L) * 300
      stages[[length(stages) + 1L]] <- data.frame(
        start = st, end = st + 300,
        stage = unname(.orElse(.oura_hypno_map[ch], NA)), day = day,
        stringsAsFactors = FALSE)
    }
    summ[[length(summ) + 1L]] <- data.frame(
      day = .orElse(day, NA),
      efficiency = .num1(r$efficiency),
      total_sleep_min = .num1(.orElse(r$total_sleep_duration, r$total)) / 60,
      time_in_bed_min = .num1(.orElse(r$time_in_bed, r$duration)) / 60,
      stringsAsFactors = FALSE)
    # Heart rate: v2 nested {interval, items, timestamp}; v1 flat hr_5min (0 = none).
    if (!is.null(r$heart_rate$items)) {
      v <- .oura_items(r$heart_rate$items)
      t0 <- .iso_time(.orElse(r$heart_rate$timestamp, r$bedtime_start), tz)
      iv <- as.numeric(.orElse(r$heart_rate$interval, 300))
      hr[[length(hr) + 1L]] <- data.frame(time = t0 + (seq_along(v) - 1L) * iv, bpm = v)
    } else if (!is.null(r$hr_5min) && !is.na(bs)) {
      v <- .oura_items(r$hr_5min); v[v == 0] <- NA_real_   # 0 = no reading
      hr[[length(hr) + 1L]] <- data.frame(time = bs + (seq_along(v) - 1L) * 300, bpm = v)
    }
    # HRV (RMSSD): v2 nested; v1 flat rmssd_5min (0 = none).
    if (!is.null(r$hrv$items)) {
      v <- .oura_items(r$hrv$items)
      t0 <- .iso_time(.orElse(r$hrv$timestamp, r$bedtime_start), tz)
      iv <- as.numeric(.orElse(r$hrv$interval, 300))
      hrv[[length(hrv) + 1L]] <- data.frame(time = t0 + (seq_along(v) - 1L) * iv, rmssd = v)
    } else if (!is.null(r$rmssd_5min) && !is.na(bs)) {
      v <- .oura_items(r$rmssd_5min); v[v == 0] <- NA_real_
      hrv[[length(hrv) + 1L]] <- data.frame(time = bs + (seq_along(v) - 1L) * 300, rmssd = v)
    }
  }

  out <- list()
  if (length(stages)) out$sleep <- do.call(rbind, stages)
  if (length(summ))   out$sleep_summary <- do.call(rbind, summ)
  if (length(hr))     out$heart_rate <- do.call(rbind, hr)
  if (length(hrv))    out$hrv <- do.call(rbind, hrv)
  if (!length(out)) stop("No recognised Oura sleep records in: ", path, call. = FALSE)
  structure(c(out, list(path = path, tz = tz)), class = "oura")
}

#' @export
print.oura <- function(x, ...) {
  mods <- setdiff(names(x), c("path", "tz"))
  cat("<oura>", length(mods), "elements:", paste(mods, collapse = ", "), "\n")
  if (!is.null(x$sleep_summary)) cat("  nights:", nrow(x$sleep_summary), "\n")
  invisible(x)
}
