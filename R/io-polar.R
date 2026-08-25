# Polar (Flow / H10) heart-rate and R-R interval ingestion.
#
# Polar exports a delimited table that may carry a heart-rate column (bpm), an
# R-R interval column (ms), and optionally a time column (seconds). The heart
# rate becomes the signal assay; the R-R intervals become PhysioEvents.

.polar_find <- function(header, pattern) {
  hit <- grep(pattern, header, ignore.case = TRUE, perl = TRUE)
  if (length(hit) == 0) NA_integer_ else hit[1]
}

# Convert a "HH:MM:SS" / "MM:SS" clock string to seconds (NA if not clock-like).
.polar_clock_to_seconds <- function(x) {
  vapply(as.character(x), function(v) {
    if (is.na(v) || !grepl("^\\d{1,2}:\\d{2}(:\\d{2})?$", v)) return(NA_real_)
    p <- as.numeric(strsplit(v, ":", fixed = TRUE)[[1]])
    if (length(p) == 3) p[1] * 3600 + p[2] * 60 + p[3] else p[1] * 60 + p[2]
  }, numeric(1), USE.NAMES = FALSE)
}

#' Read a Polar heart-rate / R-R interval export
#'
#' Reads a Polar (Flow / H10) export into a `PhysioExperiment`. A heart-rate
#' column (bpm) becomes the `"raw"` assay; R-R intervals (ms) are attached as
#' [PhysioCore::PhysioEvents] (one event per beat, with onset at the cumulative
#' R-R time and the interval in the value). When only R-R intervals are present,
#' instantaneous heart rate (60000 / R-R) is used as the signal.
#'
#' @param path Path to a Polar `.csv`/`.txt` export.
#' @param sep Field separator (default: comma).
#' @return A `PhysioExperiment`; R-R intervals are available via
#'   [PhysioCore::getEvents()].
#' @references Polar. "Flow / H10 heart-rate and R-R export."
#' @seealso [readEmpaticaE4()], [readShimmer()]
#' @export
#' @examples
#' f <- system.file("extdata", "polar_hr.csv", package = "PhysioDevices")
#' if (nzchar(f)) {
#'   pe <- readPolar(f)
#'   PhysioCore::nEvents(PhysioCore::getEvents(pe))
#' }
readPolar <- function(path, sep = ",") {
  if (!file.exists(path)) stop("Polar file not found: ", path, call. = FALSE)
  lines <- readLines(path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) < 2) stop("Polar export has no data: ", path, call. = FALSE)

  header <- trimws(strsplit(lines[1], sep, fixed = TRUE)[[1]])
  # Character cell matrix (keeps clock-formatted time columns intact); reject
  # ragged rows rather than let rbind recycle them.
  cells <- lapply(lines[-1], function(l) trimws(strsplit(l, sep, fixed = TRUE)[[1]]))
  lens <- lengths(cells)
  if (length(unique(lens)) != 1L) {
    stop("inconsistent column count across Polar data rows: ", path,
         call. = FALSE)
  }
  cell_mat <- matrix(unlist(cells), nrow = length(cells), byrow = TRUE)
  data_mat <- suppressWarnings(matrix(as.numeric(cell_mat), nrow = nrow(cell_mat)))
  colnames(data_mat) <- header

  # Column matching with a leading non-alphanumeric boundary to avoid substring
  # false positives (e.g. "hr" inside "Threshold").
  hr_col <- .polar_find(header, "(^|[^[:alnum:]])(hr|heart)")
  rr_col <- .polar_find(header, "(^|[^[:alnum:]])(r-?r|ibi)|interval")
  time_col <- .polar_find(header, "(^|[^[:alnum:]])(time|timestamp|sample|elapsed)")
  if (is.na(hr_col) && is.na(rr_col)) {
    stop("no heart-rate or R-R column found in Polar export: ", path,
         call. = FALSE)
  }

  # Sampling rate from a time column (numeric seconds, or a HH:MM:SS clock),
  # else 1 Hz.
  rate <- 1
  if (!is.na(time_col) && nrow(cell_mat) >= 2) {
    tvals <- data_mat[, time_col]
    if (all(is.na(tvals))) tvals <- .polar_clock_to_seconds(cell_mat[, time_col])
    dt <- stats::median(diff(tvals), na.rm = TRUE)
    if (!is.na(dt) && dt > 0) rate <- 1 / dt
  }

  if (!is.na(hr_col)) {
    hr <- data_mat[, hr_col, drop = FALSE]
  } else {
    hr <- matrix(60000 / data_mat[, rr_col], ncol = 1)
    rate <- NA_real_  # R-R derived: irregularly sampled
  }
  colnames(hr) <- "HR"

  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = hr),
    colData = S4Vectors::DataFrame(label = "HR", unit = "bpm"),
    metadata = list(source_device = "Polar"),
    samplingRate = rate)

  # R-R intervals -> events.
  if (!is.na(rr_col)) {
    rr_ms <- data_mat[, rr_col]
    rr_ms <- rr_ms[!is.na(rr_ms)]
    if (length(rr_ms) > 0) {
      rr_s <- rr_ms / 1000
      onset <- cumsum(rr_s) - rr_s  # start time of each beat interval
      pe <- setEvents(pe, PhysioEvents(
        onset = onset, duration = rr_s,
        type = rep("RR", length(rr_ms)),
        value = as.character(rr_ms)))
    }
  }

  logStep(pe, "readPolar", params = list(n_beats = if (!is.na(rr_col))
    sum(!is.na(data_mat[, rr_col])) else 0L, rate = rate))
}
