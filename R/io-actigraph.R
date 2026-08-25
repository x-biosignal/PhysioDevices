# Research-grade raw accelerometer readers: ActiGraph GT3X and Axivity CWA.
#
# These are binary formats (the field standards for physical-activity and sleep
# accelerometry: ActiGraph in US cohorts, Axivity AX3/AX6 in UK Biobank and other
# large studies). Rather than re-implement their bit-packed decoders, this file
# delegates to the validated `read.gt3x` and `GGIRread` packages and adapts their
# output into the ecosystem's tri-axial-acceleration `PhysioExperiment` (the same
# shape as `PhysioWearable::accelToPhysioExperiment()`: an `acceleration` assay
# with x/y/z columns in g), so it feeds `PhysioWearable::computeENMO()` /
# `summarizeFreeLiving()` directly.

# Build the canonical tri-axial acceleration PhysioExperiment.
.accel_experiment <- function(m, sampling_rate, unit = "g", metadata = list()) {
  m <- as.matrix(m)
  storage.mode(m) <- "double"
  colnames(m) <- c("x", "y", "z")
  if (!is.numeric(sampling_rate) || length(sampling_rate) != 1L ||
      !is.finite(sampling_rate) || sampling_rate <= 0) {
    stop("could not determine a valid sampling rate.", call. = FALSE)
  }
  PhysioExperiment(
    assays = SimpleList(acceleration = m),
    colData = DataFrame(label = c("x", "y", "z"), type = "accel", unit = unit),
    samplingRate = as.numeric(sampling_rate),
    metadata = metadata)
}

#' Read an ActiGraph GT3X accelerometer file
#'
#' Reads a raw ActiGraph `.gt3x` file (the common US physical-activity /
#' actigraphy device format) into a tri-axial-acceleration `PhysioExperiment`.
#' The binary decode is done by the \pkg{read.gt3x} package; the result is the
#' same shape as [PhysioWearable::accelToPhysioExperiment()], so it feeds the
#' free-living accelerometry pipeline (`computeENMO()`, `summarizeFreeLiving()`).
#'
#' @param path Path to a `.gt3x` file.
#' @param imputeZeroes If `TRUE` (default) idle-sleep-mode gaps are filled with
#'   zeroes (passed to [read.gt3x::read.gt3x()]) so the series stays regularly
#'   sampled.
#' @return A `PhysioExperiment` with an `acceleration` assay (x/y/z, g) at the
#'   device sample rate; device metadata in `metadata()`.
#' @seealso [readCWA()], [PhysioWearable::readAccelCSV()]
#' @references ActiGraph GT3X format; Neishabouri A et al. read.gt3x.
#' @export
#' @examples
#' \dontrun{
#' pe <- readGT3X("subject.gt3x")
#' acc <- SummarizedExperiment::assay(pe, "acceleration")
#' PhysioWearable::computeENMO(acc, sampling_rate = samplingRate(pe))
#' }
readGT3X <- function(path, imputeZeroes = TRUE) {
  if (!requireNamespace("read.gt3x", quietly = TRUE)) {
    stop("The 'read.gt3x' package is required to read ActiGraph .gt3x files. ",
         "Install it with: install.packages('read.gt3x')", call. = FALSE)
  }
  if (!is.character(path) || length(path) != 1L || !nzchar(path) || !file.exists(path)) {
    stop("ActiGraph .gt3x file not found: ", path, call. = FALSE)
  }
  x <- read.gt3x::read.gt3x(path, asDataFrame = TRUE, imputeZeroes = imputeZeroes)
  sr <- attr(x, "sample_rate")
  if (is.null(sr) || !is.finite(sr) || sr <= 0) {
    stop("could not determine the sample rate from: ", path, call. = FALSE)
  }
  .accel_experiment(
    x[, c("X", "Y", "Z")], sr, unit = "g",
    metadata = list(source_device = "ActiGraph",
                    serial = attr(x, "serial_prefix"),
                    start_time = if (nrow(x)) x$time[1] else NULL,
                    source_file = basename(path)))
}

#' Read an Axivity AX3/AX6 CWA accelerometer file
#'
#' Reads a raw Axivity `.cwa` file (the accelerometer format used by UK Biobank
#' and other large cohorts) into a tri-axial-acceleration `PhysioExperiment` via
#' the \pkg{GGIRread} package, in the same shape as [readGT3X()] /
#' [PhysioWearable::accelToPhysioExperiment()].
#'
#' @param path Path to a `.cwa` file.
#' @param start,end Block range to read (1-based). `end = NULL` (default) reads
#'   the whole file. For very long recordings, read in ranges.
#' @return A `PhysioExperiment` with an `acceleration` assay (x/y/z, g) at the
#'   device sample rate.
#' @seealso [readGT3X()], [PhysioWearable::readAccelCSV()]
#' @references Axivity AX3/AX6; GGIRread::readAxivity.
#' @export
#' @examples
#' \dontrun{
#' pe <- readCWA("subject.cwa")
#' acc <- SummarizedExperiment::assay(pe, "acceleration")
#' enmo <- PhysioWearable::computeENMO(acc, sampling_rate = samplingRate(pe))
#' }
readCWA <- function(path, start = 1, end = NULL) {
  if (!requireNamespace("GGIRread", quietly = TRUE)) {
    stop("The 'GGIRread' package is required to read Axivity .cwa files. ",
         "Install it with: install.packages('GGIRread')", call. = FALSE)
  }
  if (!is.character(path) || length(path) != 1L || !nzchar(path) || !file.exists(path)) {
    stop("Axivity .cwa file not found: ", path, call. = FALSE)
  }
  if (is.null(end)) {                       # whole file: read the header for the block count
    hdr <- GGIRread::readAxivity(path, start = 1, end = 1)$header
    end <- .orElse(hdr$blocks, 1e7)
  }
  d <- GGIRread::readAxivity(path, start = start, end = end)
  .accel_experiment(
    d$data[, c("x", "y", "z")], d$header$frequency, unit = "g",
    metadata = list(source_device = "Axivity",
                    serial = d$header$uniqueSerialCode,
                    start_time = d$header$start,
                    source_file = basename(path)))
}

#' Read a GENEActiv .bin accelerometer file
#'
#' Reads a raw GENEActiv `.bin` file (another research accelerometer used in
#' large cohorts) into a tri-axial-acceleration `PhysioExperiment`, in the same
#' shape as [readGT3X()] / [readCWA()], via the \pkg{GGIRread} package.
#'
#' @param path Path to a `.bin` file.
#' @param start,end Page range to read (1-based). `end = NULL` (default) reads the
#'   whole file.
#' @param sampling_rate Optional sample-rate override (Hz), used when the header
#'   does not report it; otherwise taken from the header or the timestamps.
#' @return A `PhysioExperiment` with an `acceleration` assay (x/y/z, g).
#' @seealso [readCWA()], [readGT3X()]
#' @references GENEActiv; GGIRread::readGENEActiv.
#' @export
#' @examples
#' \dontrun{
#' pe <- readGENEActiv("subject.bin")
#' }
readGENEActiv <- function(path, start = 1, end = NULL, sampling_rate = NULL) {
  if (!requireNamespace("GGIRread", quietly = TRUE)) {
    stop("The 'GGIRread' package is required to read GENEActiv .bin files. ",
         "Install it with: install.packages('GGIRread')", call. = FALSE)
  }
  if (!is.character(path) || length(path) != 1L || !nzchar(path) || !file.exists(path)) {
    stop("GENEActiv .bin file not found: ", path, call. = FALSE)
  }
  if (is.null(end)) {
    hdr <- GGIRread::readGENEActiv(path, start = 1, end = 1)$header
    end <- .orElse(hdr$numBlocksTotal, 1e7)
  }
  d <- GGIRread::readGENEActiv(path, start = start, end = end)
  sr <- if (!is.null(sampling_rate)) sampling_rate else d$header$SampleRate
  if (is.null(sr) || is.na(sr) || sr <= 0) {     # header lacks it -> derive from timestamps
    dt <- stats::median(diff(as.numeric(d$data.out$time)), na.rm = TRUE)
    if (is.finite(dt) && dt > 0) sr <- 1 / dt
  }
  .accel_experiment(
    d$data.out[, c("x", "y", "z")], sr, unit = "g",
    metadata = list(source_device = "GENEActiv",
                    serial = d$header$serial_number,
                    start_time = d$header$StarTime,
                    source_file = basename(path)))
}
