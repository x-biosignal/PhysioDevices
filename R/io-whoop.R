# Whoop reader.
#
# Whoop's data export is a set of CSVs (sleeps.csv, physiological_cycles.csv,
# workouts.csv). It reports per-night / per-cycle SUMMARIES (stage durations,
# HRV, resting HR, recovery, blood oxygen), not epoch-level stages, so the reader
# returns tidy daily-summary tables. Column names carry units/spaces, so they are
# matched by name heuristics (read with check.names = FALSE).

# numeric column whose name matches `pat` (NULL if absent)
.csv_num <- function(d, pat) {
  i <- grep(pat, names(d), ignore.case = TRUE)[1]
  if (is.na(i)) NULL else suppressWarnings(as.numeric(gsub("[^0-9eE.+-]", "", as.character(d[[i]]))))
}
.csv_chr <- function(d, pat) {
  i <- grep(pat, names(d), ignore.case = TRUE)[1]
  if (is.na(i)) NULL else as.character(d[[i]])
}

#' Read a Whoop data export
#'
#' Parses a Whoop CSV export directory into tidy daily-summary tables: `sleep`
#' (per-night stage durations, efficiency, HRV, respiratory rate) and `recovery`
#' (recovery score, resting heart rate, HRV, blood oxygen, skin temperature).
#' Whoop exports summaries, not epoch-level stages.
#'
#' @param path Directory of the Whoop export (searched recursively), or a file /
#'   vector of files.
#' @return A `whoop` object: a list with `sleep` and/or `recovery` data frames,
#'   plus `path`.
#' @seealso [readOura()], [readFitbit()]
#' @references Whoop data export.
#' @export
#' @examples
#' \dontrun{
#' w <- readWhoop("my_whoop_export")
#' w$recovery
#' }
readWhoop <- function(path) {
  if (length(path) > 1L) files <- path[file.exists(path)]
  else if (dir.exists(path)) files <- list.files(path, pattern = "\\.csv$", recursive = TRUE,
                                                 full.names = TRUE, ignore.case = TRUE)
  else if (file.exists(path)) files <- path
  else stop("Whoop path not found: ", path, call. = FALSE)
  if (!length(files)) stop("No .csv files found under: ", path, call. = FALSE)

  bn <- tolower(basename(files))
  rd <- function(f) tryCatch(utils::read.csv(f, stringsAsFactors = FALSE, check.names = FALSE),
                             error = function(e) {
                               warning("Skipping unreadable Whoop CSV '", basename(f), "'.",
                                       call. = FALSE); NULL })
  out <- list()

  sl <- files[grepl("sleep", bn)]
  if (length(sl)) {
    d <- rd(sl[1])
    if (!is.null(d)) out$sleep <- data.frame(
      day = .orElse(.csv_chr(d, "cycle start|^start|date"), NA),
      efficiency = .orElse(.csv_num(d, "efficiency"), NA),
      light_min = .orElse(.csv_num(d, "light"), NA),
      deep_min = .orElse(.csv_num(d, "deep|sws"), NA),
      rem_min = .orElse(.csv_num(d, "rem"), NA),
      awake_min = .orElse(.csv_num(d, "awake"), NA),
      hrv_ms = .orElse(.csv_num(d, "variability|hrv"), NA),
      respiratory_rate = .orElse(.csv_num(d, "respirat"), NA),
      stringsAsFactors = FALSE)
  }
  cy <- files[grepl("physiolog|cycle|recovery", bn) & !grepl("sleep", bn)]
  if (length(cy)) {
    d <- rd(cy[1])
    if (!is.null(d)) out$recovery <- data.frame(
      day = .orElse(.csv_chr(d, "cycle start|^start|date"), NA),
      recovery = .orElse(.csv_num(d, "recovery"), NA),
      resting_hr = .orElse(.csv_num(d, "resting"), NA),
      hrv_ms = .orElse(.csv_num(d, "variability|hrv"), NA),
      spo2 = .orElse(.csv_num(d, "oxygen|spo2"), NA),
      skin_temp_c = .orElse(.csv_num(d, "skin temp|temperature"), NA),
      stringsAsFactors = FALSE)
  }

  if (!length(out)) {
    stop("No recognised Whoop CSVs under: ", path,
         " (expected sleeps.csv / physiological_cycles.csv).", call. = FALSE)
  }
  structure(c(out, list(path = path)), class = "whoop")
}

#' @export
print.whoop <- function(x, ...) {
  mods <- setdiff(names(x), "path")
  cat("<whoop>", paste(mods, collapse = ", "), "\n")
  invisible(x)
}
