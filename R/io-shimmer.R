# Shimmer GSR3+ (Consensys export) ingestion.
#
# A Consensys CSV export begins with an optional `sep=<char>` line, then a row
# of column headers (device-prefixed, e.g. Shimmer_1234_GSR_Skin_Conductance_CAL),
# then a row of units, then the tab/comma-separated calibrated data. The `_CAL`
# columns are already in physical units; the timestamp column gives the rate.

# Strip the "Shimmer_<id>_" prefix and "_CAL"/"_RAW" suffix from a column name.
.shimmer_clean_label <- function(x) {
  x <- sub("^Shimmer_[^_]+_", "", x)
  x <- sub("_(CAL|RAW)$", "", x)
  x
}

#' Read a Shimmer GSR3+ Consensys CSV export
#'
#' Reads a Shimmer GSR3+ Consensys export (GSR / skin conductance, PPG,
#' accelerometer) into a `PhysioExperiment`. The calibrated (`_CAL`) columns are
#' read in their physical units; the timestamp column determines the sampling
#' rate; and each channel's unit (from the export's unit row) is stored in the
#' column metadata.
#'
#' @param path Path to a Shimmer Consensys `.csv` file.
#' @param sep Field separator. By default it is taken from a leading
#'   `sep=<char>` line, falling back to a tab.
#' @return A `PhysioExperiment` with one channel per calibrated signal.
#' @references Shimmer. "Consensys — data export format."
#' @seealso [readEmpaticaE4()], [readPolar()]
#' @export
#' @examples
#' f <- system.file("extdata", "shimmer_gsr3.csv", package = "PhysioDevices")
#' if (nzchar(f)) {
#'   pe <- readShimmer(f)
#'   channelNames(pe)
#' }
readShimmer <- function(path, sep = NULL) {
  if (!file.exists(path)) stop("Shimmer file not found: ", path, call. = FALSE)
  lines <- readLines(path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]

  # Optional leading "sep=<char>" declaration.
  if (grepl("^sep=", lines[1])) {
    if (is.null(sep)) {
      sep <- sub("^sep=", "", lines[1])
      if (identical(sep, "\\t")) sep <- "\t"
    }
    lines <- lines[-1]
  }
  if (is.null(sep)) sep <- "\t"

  if (length(lines) < 3) {
    stop("Shimmer export has no data rows: ", path, call. = FALSE)
  }
  header <- strsplit(lines[1], sep, fixed = TRUE)[[1]]
  units <- strsplit(lines[2], sep, fixed = TRUE)[[1]]
  data_mat <- .read_num_matrix(lines[-(1:2)], sep, ncol = length(header))
  colnames(data_mat) <- header

  # Timestamp column -> sampling rate.
  ts_col <- grep("Timestamp", header, ignore.case = TRUE)[1]
  rate <- NA_real_
  if (!is.na(ts_col) && nrow(data_mat) >= 2) {
    dt <- stats::median(diff(data_mat[, ts_col]), na.rm = TRUE)
    if (!is.na(dt) && dt > 0) {
      # Unix timestamp columns are in milliseconds ("ms" unit or a *_Unix_*
      # column); otherwise assume seconds.
      unit_ts <- if (length(units) >= ts_col) tolower(units[ts_col]) else ""
      is_ms <- grepl("^ms$|millisec", unit_ts) ||
        grepl("unix", header[ts_col], ignore.case = TRUE)
      rate <- (if (is_ms) 1000 else 1) / dt
    }
  }

  sig_cols <- setdiff(seq_along(header), ts_col)
  sig_cols <- sig_cols[!is.na(header[sig_cols]) & nzchar(header[sig_cols])]
  if (length(sig_cols) == 0) {
    stop("no signal columns found in Shimmer export: ", path, call. = FALSE)
  }
  data <- data_mat[, sig_cols, drop = FALSE]
  labels <- vapply(header[sig_cols], .shimmer_clean_label, character(1),
                   USE.NAMES = FALSE)
  colnames(data) <- labels
  # Index element-wise so a short units row only loses the missing entries.
  ch_units <- units[sig_cols]

  pe <- PhysioExperiment(
    assays = S4Vectors::SimpleList(raw = data),
    colData = S4Vectors::DataFrame(label = labels,
                                   unit = as.character(ch_units)),
    metadata = list(source_device = "Shimmer GSR3+"),
    samplingRate = rate)
  logStep(pe, "readShimmer", params = list(n_channels = length(labels),
                                           rate = rate))
}
