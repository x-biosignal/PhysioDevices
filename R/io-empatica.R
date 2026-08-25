# Empatica E4 (CSV session) and EmbracePlus (Avro container) ingestion.
#
# An E4 session is a directory of per-signal CSV files. Each signal CSV begins
# with two header rows: row 1 is the UTC start time (one value per column) and
# row 2 is the sampling rate (one value per column); the remaining rows are the
# samples. IBI.csv and tags.csv follow their own layouts.

# Parse delimited numeric data rows into a matrix, rejecting ragged rows (which
# rbind would silently recycle). Returns a 0-row matrix with `ncol` columns when
# `body` is empty.
.read_num_matrix <- function(body, sep = ",", ncol = 1L) {
  if (length(body) == 0) return(matrix(numeric(0), nrow = 0, ncol = ncol))
  parts <- lapply(body, function(l) {
    suppressWarnings(as.numeric(strsplit(l, sep, fixed = TRUE)[[1]]))
  })
  lens <- lengths(parts)
  if (length(unique(lens)) != 1L) {
    stop(sprintf("inconsistent column count across data rows (%d..%d)",
                 min(lens), max(lens)), call. = FALSE)
  }
  matrix(unlist(parts), nrow = length(parts), ncol = lens[1], byrow = TRUE)
}

# Signal -> (file, stream name, sampling rate, channel labels). Rates are the
# fixed E4 device rates; the value in the file header is authoritative and used
# when present.
.E4_SIGNALS <- list(
  list(file = "EDA.csv",  name = "eda",  rate = 4,  labels = "EDA"),
  list(file = "BVP.csv",  name = "bvp",  rate = 64, labels = "BVP"),
  list(file = "ACC.csv",  name = "acc",  rate = 32, labels = c("ACC_x", "ACC_y", "ACC_z")),
  list(file = "TEMP.csv", name = "temp", rate = 4,  labels = "TEMP"),
  list(file = "HR.csv",   name = "hr",   rate = 1,  labels = "HR"))

# Parse one E4 signal CSV: returns list(data = matrix, start_time, rate).
.read_e4_signal <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) < 2) {
    stop("E4 signal file is too short: ", path, call. = FALSE)
  }
  start_hdr <- as.numeric(strsplit(lines[1], ",", fixed = TRUE)[[1]])
  start_time <- start_hdr[1]
  rate <- as.numeric(strsplit(lines[2], ",", fixed = TRUE)[[1]])[1]
  # The header row has one value per column, so it fixes the channel count even
  # for a header-only (0-sample) file.
  data <- .read_num_matrix(lines[-(1:2)], ",", ncol = length(start_hdr))
  list(data = data, start_time = start_time, rate = rate)
}

# Parse IBI.csv into (onset seconds since session start, ibi seconds).
.read_e4_ibi <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) < 2) return(NULL)
  body <- lines[-1]  # row 1 = "<start_time>, IBI"
  m <- do.call(rbind, lapply(body, function(l) {
    as.numeric(strsplit(l, ",", fixed = TRUE)[[1]])[1:2]
  }))
  if (is.null(m) || nrow(m) == 0) return(NULL)
  data.frame(onset = m[, 1], ibi = m[, 2])
}

#' Read an Empatica E4 CSV session directory
#'
#' Reads an Empatica E4 session (a directory of per-signal CSV files) into a
#' [PhysioCore::MultiRatePhysioExperiment]. Each present signal (EDA at 4 Hz,
#' BVP at 64 Hz, ACC at 32 Hz, TEMP at 4 Hz, HR at 1 Hz) becomes its own stream
#' at its native rate, and the per-signal UTC start times are aligned on a
#' common clock via per-stream offsets. Inter-beat intervals (`IBI.csv`) and
#' event tags (`tags.csv`) are attached as events.
#'
#' @param dir Path to an E4 session directory.
#' @return A [PhysioCore::MultiRatePhysioExperiment] with one stream per signal.
#' @references Empatica. "E4 wristband data — exported CSV file format."
#' @seealso [readEmbracePlusAvro()], [readShimmer()]
#' @export
#' @examples
#' d <- system.file("extdata", "e4_sample", package = "PhysioDevices")
#' if (nzchar(d)) {
#'   mr <- readEmpaticaE4(d)
#'   PhysioCore::streamNames(mr)
#' }
readEmpaticaE4 <- function(dir) {
  if (!dir.exists(dir)) stop("session directory not found: ", dir, call. = FALSE)

  present <- Filter(function(s) file.exists(file.path(dir, s$file)), .E4_SIGNALS)
  if (length(present) == 0) {
    stop("no E4 signal files (EDA/BVP/ACC/TEMP/HR.csv) found in: ", dir,
         call. = FALSE)
  }

  parsed <- lapply(present, function(s) {
    sig <- .read_e4_signal(file.path(dir, s$file))
    labels <- s$labels
    if (ncol(sig$data) != length(labels)) {
      labels <- paste0(s$name, seq_len(ncol(sig$data)))
    }
    rate <- if (is.na(sig$rate) || sig$rate <= 0) s$rate else sig$rate
    pe <- PhysioExperiment(
      assays = S4Vectors::SimpleList(raw = sig$data),
      colData = S4Vectors::DataFrame(label = labels),
      metadata = list(source_device = "Empatica E4",
                      start_time = sig$start_time),
      samplingRate = rate)
    pe <- logStep(pe, "readEmpaticaE4",
                  params = list(signal = s$name, rate = rate))
    list(name = s$name, pe = pe, start_time = sig$start_time)
  })

  streams <- stats::setNames(lapply(parsed, `[[`, "pe"),
                             vapply(parsed, `[[`, "", "name"))
  starts <- vapply(parsed, `[[`, numeric(1), "start_time")
  t0 <- min(starts, na.rm = TRUE)
  offsets <- stats::setNames(starts - t0, names(streams))

  # IBI (inter-beat intervals) and tags (button presses) are session-level
  # events. The MultiRate container has no event slot, so attach them, with
  # onsets relative to the session start, to a stream that begins at t0.
  onset <- numeric(0); duration <- numeric(0)
  etype <- character(0); evalue <- character(0)
  ibi_path <- file.path(dir, "IBI.csv")
  if (file.exists(ibi_path)) {
    ibi <- .read_e4_ibi(ibi_path)
    if (!is.null(ibi)) {
      onset <- c(onset, ibi$onset); duration <- c(duration, ibi$ibi)
      etype <- c(etype, rep("IBI", nrow(ibi)))
      evalue <- c(evalue, as.character(ibi$ibi))
    }
  }
  tags_path <- file.path(dir, "tags.csv")
  if (file.exists(tags_path)) {
    tag_times <- suppressWarnings(as.numeric(readLines(tags_path, warn = FALSE)))
    tag_times <- tag_times[!is.na(tag_times)]
    if (length(tag_times) > 0) {
      onset <- c(onset, tag_times - t0)
      duration <- c(duration, rep(0, length(tag_times)))
      etype <- c(etype, rep("tag", length(tag_times)))
      evalue <- c(evalue, rep("", length(tag_times)))
    }
  }
  if (length(onset) > 0) {
    host <- which(offsets == 0)[1]
    if (is.na(host)) host <- 1L   # fall back if no stream resolves to offset 0
    streams[[host]] <- setEvents(streams[[host]], PhysioEvents(
      onset = onset, duration = duration, type = etype, value = evalue))
  }

  ref_rate <- max(vapply(streams, samplingRate, numeric(1)), na.rm = TRUE)
  MultiRatePhysioExperiment(streams = streams, offsets = offsets,
                            reference_rate = ref_rate, t0 = t0)
}

# --- EmbracePlus Avro -------------------------------------------------------

#' Is an Avro backend available?
#'
#' @return `TRUE` when the Python `fastavro` module is reachable via
#'   \pkg{reticulate}.
#' @seealso [readEmbracePlusAvro()]
#' @export
#' @examples
#' hasAvroBackend()
hasAvroBackend <- function() {
  requireNamespace("reticulate", quietly = TRUE) &&
    isTRUE(tryCatch(reticulate::py_module_available("fastavro"),
                    error = function(e) FALSE))
}

# EmbracePlus rawData signal field -> stream name + channel labels.
.EMBRACE_SIGNALS <- list(
  list(field = "eda",           name = "eda",  labels = "EDA"),
  list(field = "bvp",           name = "bvp",  labels = "BVP"),
  list(field = "temperature",   name = "temp", labels = "TEMP"),
  list(field = "accelerometer", name = "acc",
       labels = c("ACC_x", "ACC_y", "ACC_z")))

#' Read an Empatica EmbracePlus Avro container
#'
#' Decodes an EmbracePlus `.avro` file into a
#' [PhysioCore::MultiRatePhysioExperiment]. Each signal in the record's
#' `rawData` (EDA, BVP, temperature, accelerometer) becomes a stream at its
#' `samplingFrequency`, aligned by its `timestampStart` (microseconds). Requires
#' an Avro backend (the Python `fastavro` module via \pkg{reticulate}; see
#' [hasAvroBackend()]).
#'
#' @param path Path to an EmbracePlus `.avro` file.
#' @return A [PhysioCore::MultiRatePhysioExperiment].
#' @references Empatica. "EmbracePlus — Avro data format."
#' @seealso [readEmpaticaE4()], [hasAvroBackend()]
#' @export
readEmbracePlusAvro <- function(path) {
  if (!file.exists(path)) stop("Avro file not found: ", path, call. = FALSE)
  if (!hasAvroBackend()) {
    stop("An Avro backend is required (install the Python 'fastavro' module ",
         "via reticulate::py_install('fastavro')).", call. = FALSE)
  }
  fastavro <- reticulate::import("fastavro", delay_load = TRUE)
  builtins <- reticulate::import_builtins()

  con <- builtins$open(path, "rb")
  records <- tryCatch(
    reticulate::py_to_r(builtins$list(fastavro$reader(con))),
    finally = con$close())
  if (length(records) == 0) stop("empty Avro file: ", path, call. = FALSE)
  raw <- records[[1]][["rawData"]]

  parsed <- list()
  starts <- numeric(0)
  for (s in .EMBRACE_SIGNALS) {
    node <- raw[[s$field]]
    if (is.null(node)) next
    sfreq <- as.numeric(node[["samplingFrequency"]])
    if (is.na(sfreq) || sfreq <= 0) next
    if (identical(s$field, "accelerometer")) {
      x <- as.numeric(node[["x"]]); y <- as.numeric(node[["y"]])
      z <- as.numeric(node[["z"]])
      if (length(x) == 0) next
      if (length(unique(c(length(x), length(y), length(z)))) != 1L) {
        stop(sprintf(paste0("accelerometer x/y/z arrays differ in length ",
                            "(%d/%d/%d) in %s"), length(x), length(y),
                     length(z), path), call. = FALSE)
      }
      data <- cbind(x, y, z)
      labels <- s$labels
    } else {
      values <- as.numeric(node[["values"]])
      if (length(values) == 0) next
      data <- matrix(values, ncol = 1)
      labels <- s$labels
    }
    start_us <- as.numeric(node[["timestampStart"]])[1]
    if (length(start_us) == 0 || is.na(start_us)) start_us <- NA_real_
    pe <- PhysioExperiment(
      assays = S4Vectors::SimpleList(raw = data),
      colData = S4Vectors::DataFrame(label = labels),
      metadata = list(source_device = "Empatica EmbracePlus",
                      start_time = start_us / 1e6),
      samplingRate = sfreq)
    pe <- logStep(pe, "readEmbracePlusAvro",
                  params = list(signal = s$name, rate = sfreq))
    parsed[[s$name]] <- pe
    starts[s$name] <- start_us / 1e6
  }

  if (length(parsed) == 0) {
    stop("no decodable signals found in Avro file: ", path, call. = FALSE)
  }
  t0 <- if (all(is.na(starts))) 0 else min(starts, na.rm = TRUE)
  offsets <- starts - t0
  offsets[is.na(offsets)] <- 0   # signals missing a start time align at t0
  ref_rate <- max(vapply(parsed, samplingRate, numeric(1)), na.rm = TRUE)
  MultiRatePhysioExperiment(streams = parsed, offsets = offsets,
                            reference_rate = ref_rate, t0 = t0)
}
