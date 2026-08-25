# BIOPAC AcqKnowledge (.acq) ingestion.
#
# The .acq binary format is version-specific and complex; this reader delegates
# parsing to the reference implementation, the Python `bioread` module (reached
# through reticulate), and maps its channels (each at its own sample rate) and
# event markers onto a MultiRatePhysioExperiment + PhysioEvents.

#' Is a BIOPAC (bioread) backend available?
#'
#' @return `TRUE` when the Python `bioread` module is reachable via
#'   \pkg{reticulate}.
#' @seealso [readBIOPAC()]
#' @export
#' @examples
#' hasBioread()
hasBioread <- function() {
  requireNamespace("reticulate", quietly = TRUE) &&
    isTRUE(tryCatch(reticulate::py_module_available("bioread"),
                    error = function(e) FALSE))
}

#' Read a BIOPAC AcqKnowledge (.acq) file
#'
#' Parses a BIOPAC AcqKnowledge `.acq` file (via the Python `bioread` module
#' through \pkg{reticulate}; see [hasBioread()]) into a
#' [PhysioCore::MultiRatePhysioExperiment]. Each acquisition channel becomes a
#' stream at its own sample rate (channels may be acquired at different rates via
#' frequency dividers), carrying its label and unit. Event markers become
#' [PhysioCore::PhysioEvents] on the fastest stream.
#'
#' @param path Path to a `.acq` file.
#' @return A [PhysioCore::MultiRatePhysioExperiment].
#' @references bioread: \url{https://github.com/uwmadison-chm/bioread}.
#' @seealso [hasBioread()], [readDelsysTrigno()], [readXsensMVNX()]
#' @export
readBIOPAC <- function(path) {
  if (!file.exists(path)) stop("BIOPAC file not found: ", path, call. = FALSE)
  if (!hasBioread()) {
    stop("The Python 'bioread' module (via reticulate) is required to read ",
         ".acq files. Install it with reticulate::py_install('bioread').",
         call. = FALSE)
  }
  bioread <- reticulate::import("bioread", delay_load = TRUE)
  df <- bioread$read_file(path)

  channels <- df$channels   # reticulate converts the Python list to an R list
  if (length(channels) == 0) {
    stop("no channels found in BIOPAC file: ", path, call. = FALSE)
  }

  names_raw <- vapply(channels, function(ch) {
    as.character(reticulate::py_to_r(ch$name))
  }, character(1))
  stream_names <- make.unique(.biopac_sanitize(names_raw), sep = "_")

  streams <- list()
  rates <- numeric(0)
  for (i in seq_along(channels)) {
    ch <- channels[[i]]
    data <- as.numeric(reticulate::py_to_r(ch$data))
    rate <- as.numeric(reticulate::py_to_r(ch$samples_per_second))[1]
    unit <- as.character(reticulate::py_to_r(ch$units))
    label <- names_raw[i]
    pe <- PhysioExperiment(
      assays = S4Vectors::SimpleList(raw = matrix(data, ncol = 1)),
      colData = S4Vectors::DataFrame(label = label, unit = unit),
      metadata = list(source_device = "BIOPAC AcqKnowledge"),
      samplingRate = rate)
    streams[[stream_names[i]]] <- logStep(pe, "readBIOPAC",
                                          params = list(channel = label,
                                                        rate = rate))
    rates[stream_names[i]] <- rate
  }

  base_rate <- as.numeric(reticulate::py_to_r(df$samples_per_second))[1]
  if (is.na(base_rate) || base_rate <= 0) base_rate <- max(rates, na.rm = TRUE)

  # Event markers -> events on the fastest stream (marker sample_index is in
  # units of the base sample rate).
  markers <- tryCatch(df$event_markers, error = function(e) NULL)
  if (is.null(markers)) markers <- list()
  if (length(markers) > 0) {
    onset <- vapply(markers, function(m) {
      as.numeric(reticulate::py_to_r(m$sample_index))[1] / base_rate
    }, numeric(1))
    text <- vapply(markers, function(m) {
      t <- reticulate::py_to_r(m$text)
      if (is.null(t) || length(t) == 0) "" else as.character(t)[1]
    }, character(1))
    fastest <- names(rates)[which.max(rates)]
    streams[[fastest]] <- setEvents(streams[[fastest]], PhysioEvents(
      onset = onset, duration = rep(0, length(onset)),
      type = rep("marker", length(onset)), value = text))
  }

  offsets <- stats::setNames(rep(0, length(streams)), names(streams))
  MultiRatePhysioExperiment(streams = streams, offsets = offsets,
                            reference_rate = max(rates, na.rm = TRUE), t0 = 0)
}

# Make a channel name safe as a stream key.
.biopac_sanitize <- function(x) {
  x <- gsub("[^A-Za-z0-9_]+", "_", x)
  x <- sub("^_+", "", x)
  x[!nzchar(x)] <- "channel"
  x
}
