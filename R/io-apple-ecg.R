# Apple Watch ECG reader
#
# The Apple Watch ECG app exports one CSV per recording: a short "key,value"
# metadata header (Recorded Date, Classification, Sample Rate, Unit, ...) then
# the single-lead voltage trace, one sample per line. The sample rate is ~512 Hz
# and the unit is microvolts. Layout wording varies by locale/OS version, so the
# reader keys off the numeric block rather than fixed line positions.

# The value from a "key,value" header line whose key matches `key_regex`.
.apple_ecg_header <- function(lines, key_regex) {
  hit <- grep(key_regex, lines, ignore.case = TRUE)
  if (!length(hit)) return(NA_character_)
  parts <- strsplit(lines[hit[1]], ",", fixed = TRUE)[[1]]
  if (length(parts) < 2) return(NA_character_)
  trimws(paste(parts[-1], collapse = ","))
}

#' Read an Apple Watch ECG recording
#'
#' Parses the single-lead ECG CSV that the Apple Watch ECG app exports into a
#' `PhysioExperiment` (one `ECG` channel). The classification, recorded date and
#' sample rate from the file header are kept in `metadata()`. The result feeds
#' the `PhysioECG` beat-detection and heart-rate-variability functions.
#'
#' @param path Path to an Apple Watch ECG `.csv` export.
#' @param default_rate Sample rate (Hz) to assume if the header has none
#'   (default 512, the Apple Watch ECG rate).
#' @return A `PhysioExperiment` with a `raw` assay of the ECG voltage
#'   (microvolts) and `samplingRate` set from the header.
#' @seealso [readAppleHealth()]
#' @references Apple Inc. Taking an ECG with the ECG app on Apple Watch.
#' @export
#' @examples
#' \dontrun{
#' ecg <- readAppleECG("ecg_2023-05-01.csv")
#' samplingRate(ecg)
#' }
readAppleECG <- function(path, default_rate = 512) {
  if (!is.character(path) || length(path) != 1L || !nzchar(path) || !file.exists(path)) {
    stop("Apple Watch ECG file not found: ", path, call. = FALSE)
  }
  lines <- readLines(path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  if (!length(lines)) stop("Apple Watch ECG file is empty: ", path, call. = FALSE)

  # Sample rate, e.g. "Sample Rate,512 Hz" -> 512.
  sr_raw <- .apple_ecg_header(lines, "sample[ _]*rate|sampling")
  sr <- suppressWarnings(as.numeric(sub("([0-9.]+).*", "\\1", sr_raw)))
  if (is.na(sr) || sr <= 0) sr <- default_rate

  unit <- .apple_ecg_header(lines, "^unit")
  if (is.na(unit) || !nzchar(unit)) unit <- "uV"
  classification <- .apple_ecg_header(lines, "classification")
  recorded <- .apple_ecg_header(lines, "recorded")

  # The voltage trace is the longest run of consecutive numeric lines (header
  # "key,value" lines have a non-numeric key, so they break the run).
  vals <- suppressWarnings(as.numeric(sub(",\\s*$", "", trimws(lines))))
  is_num <- !is.na(vals)
  r <- rle(is_num)
  if (!any(r$values)) {
    stop("No numeric ECG samples found in: ", path, call. = FALSE)
  }
  ends <- cumsum(r$lengths)
  starts <- ends - r$lengths + 1L
  num_runs <- which(r$values)
  best <- num_runs[which.max(r$lengths[num_runs])]
  v <- vals[starts[best]:ends[best]]

  m <- matrix(v, ncol = 1, dimnames = list(NULL, "ECG"))
  pe <- PhysioExperiment(
    assays = SimpleList(raw = m),
    colData = DataFrame(label = "ECG", unit = unit),
    metadata = list(source_device = "Apple Watch",
                    classification = classification,
                    recorded_date = recorded,
                    source_file = basename(path)),
    samplingRate = sr)
  pe
}
