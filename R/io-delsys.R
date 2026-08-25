# Delsys Trigno (File Utility / EMGworks CSV) ingestion.
#
# A Trigno CSV export pairs every value column with its own "X[s]" time column,
# because EMG (~2000 Hz) and the IMU channels (accelerometer / gyroscope /
# magnetometer, lower rate) are sampled at different rates. Lower-rate columns
# are blank on rows past their sample count. EMG channels become one stream and
# the IMU channels another, each at its own rate.

# Classify a Trigno channel name into a sensor modality.
.delsys_type <- function(name) {
  n <- toupper(name)
  if (grepl("EMG", n)) "EMG"
  else if (grepl("ACC", n)) "ACC"
  else if (grepl("GYR", n)) "GYRO"
  else if (grepl("MAG", n)) "MAG"
  else "OTHER"
}

# Sensor number from a channel name ("Sensor 3: EMG ..." or "EMG3 ...").
.delsys_sensor <- function(name) {
  m <- regmatches(name, regexpr("[Ss]ensor\\s*\\d+", name))
  if (length(m) == 1 && nzchar(m)) {
    return(as.integer(sub(".*?(\\d+).*", "\\1", m)))
  }
  m2 <- regmatches(name, regexpr("\\d+", name))
  if (length(m2) == 1 && nzchar(m2)) as.integer(m2) else NA_integer_
}

# Clean a channel label: drop the "Sensor N:" prefix and a trailing "(unit)".
.delsys_label <- function(name) {
  x <- sub("^\\s*[Ss]ensor\\s*\\d+\\s*:?\\s*", "", name)
  x <- sub("\\s*\\([^)]*\\)\\s*$", "", x)
  trimws(x)
}

#' Read a Delsys Trigno CSV export
#'
#' Parses a Delsys Trigno File Utility / EMGworks CSV export into a
#' [PhysioCore::MultiRatePhysioExperiment]. EMG channels (high rate) and the IMU
#' channels (accelerometer / gyroscope / magnetometer, lower rate) are separated
#' into their own streams, each at the rate implied by its per-channel `X[s]`
#' time column, with per-sensor column metadata (sensor number and modality).
#'
#' @param path Path to a Trigno `.csv` export.
#' @param sep Field separator (default: comma).
#' @return A [PhysioCore::MultiRatePhysioExperiment] with an `"emg"` stream and,
#'   when present, an `"imu"` stream.
#' @references Delsys. "Trigno File Utility / EMGworks export."
#' @seealso [readXsensMVNX()], [readBIOPAC()]
#' @export
#' @examples
#' f <- system.file("extdata", "delsys_trigno.csv", package = "PhysioDevices")
#' if (nzchar(f)) {
#'   mr <- readDelsysTrigno(f)
#'   PhysioCore::streamNames(mr)
#' }
readDelsysTrigno <- function(path, sep = ",") {
  if (!file.exists(path)) stop("Delsys file not found: ", path, call. = FALSE)
  lines <- readLines(path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]

  # Find the header row: the first line whose fields include an "X[s]" column.
  hdr_row <- which(vapply(lines, function(l) {
    any(grepl("^X\\[s\\]", trimws(strsplit(l, sep, fixed = TRUE)[[1]])))
  }, logical(1)))[1]
  if (is.na(hdr_row)) {
    stop("no Trigno data header (with an 'X[s]' column) found in: ", path,
         call. = FALSE)
  }
  if (hdr_row >= length(lines)) {
    stop("Trigno export has a data header but no data rows: ", path,
         call. = FALSE)
  }
  header <- trimws(strsplit(lines[hdr_row], sep, fixed = TRUE)[[1]])
  body <- lines[(hdr_row + 1):length(lines)]
  ncol_h <- length(header)

  # Rows shorter than the header are legitimate (lower-rate columns run out and
  # are blank); rows LONGER than the header indicate corruption.
  cells <- lapply(body, function(l) strsplit(l, sep, fixed = TRUE)[[1]])
  too_long <- which(lengths(cells) > ncol_h)
  if (length(too_long) > 0) {
    stop(sprintf("Trigno data row %d has more fields than the header",
                 too_long[1] + hdr_row), call. = FALSE)
  }
  cells <- lapply(cells, function(r) {
    length(r) <- ncol_h    # pad short rows (trailing blanks) to header width
    r
  })
  cell_mat <- matrix(unlist(cells), nrow = length(cells), byrow = TRUE)
  num <- suppressWarnings(matrix(as.numeric(cell_mat), nrow = nrow(cell_mat)))

  # Pair each value column with the NEAREST PRECEDING "X[s]" time column. This
  # handles both per-channel time columns and a single shared time column.
  x_cols <- which(grepl("^X\\[s\\]", header))
  val_cols <- setdiff(seq_len(ncol_h), x_cols)

  chans <- lapply(val_cols, function(v) {
    pre <- x_cols[x_cols < v]
    if (length(pre) == 0) return(NULL)   # value column with no time column
    tcol <- num[, max(pre)]; vcol <- num[, v]
    keep <- !is.na(vcol)
    times <- tcol[keep]; values <- vcol[keep]
    if (length(values) == 0) return(NULL)
    rate <- if (length(times) >= 2) 1 / stats::median(diff(times)) else NA_real_
    list(name = header[v], type = .delsys_type(header[v]),
         sensor = .delsys_sensor(header[v]),
         label = .delsys_label(header[v]),
         values = values, rate = rate, n = length(values))
  })
  chans <- Filter(Negate(is.null), chans)

  emg <- Filter(function(c) c$type == "EMG", chans)
  imu <- Filter(function(c) c$type %in% c("ACC", "GYRO", "MAG"), chans)

  # Channels of a modality that differ in sample count (e.g. accel vs gyro at
  # different rates) become separate streams so no data is lost.
  streams <- c(.delsys_streams(emg, "emg"), .delsys_streams(imu, "imu"))
  if (length(streams) == 0) {
    stop("no EMG or IMU channels found in Trigno export: ", path, call. = FALSE)
  }

  rates <- vapply(streams, samplingRate, numeric(1))
  offsets <- stats::setNames(rep(0, length(streams)), names(streams))
  MultiRatePhysioExperiment(streams = streams, offsets = offsets,
                            reference_rate = max(rates, na.rm = TRUE), t0 = 0)
}

# Split a modality's channels into one stream per distinct sample count.
.delsys_streams <- function(chans, base) {
  if (length(chans) == 0) return(list())
  ns <- vapply(chans, `[[`, integer(1), "n")
  groups <- split(chans, ns)
  out <- list()
  for (i in seq_along(groups)) {
    nm <- if (length(groups) == 1) base else paste0(base, i)
    out[[nm]] <- .delsys_stream(groups[[i]], toupper(base))
  }
  out
}

# Assemble one stream from a set of channels (which must share a sample count).
.delsys_stream <- function(chans, modality) {
  n <- vapply(chans, `[[`, integer(1), "n")
  if (length(unique(n)) != 1L) {
    stop(sprintf(
      "%s channels have differing sample counts (%s); cannot form one stream",
      modality, paste(range(n), collapse = "..")), call. = FALSE)
  }
  data <- do.call(cbind, lapply(chans, `[[`, "values"))
  labels <- vapply(chans, `[[`, "", "label")
  colnames(data) <- labels
  rate <- stats::median(vapply(chans, `[[`, numeric(1), "rate"), na.rm = TRUE)
  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = data),
    colData = S4Vectors::DataFrame(
      label = labels,
      sensor = vapply(chans, `[[`, integer(1), "sensor"),
      type = vapply(chans, `[[`, "", "type")),
    metadata = list(source_device = "Delsys Trigno", modality = modality),
    samplingRate = rate)
  logStep(pe, "readDelsysTrigno", params = list(modality = modality,
                                                n_channels = length(chans)))
}
