# Apple Health export reader
#
# Apple's Health app exports a `export.xml` in which every sample is a
# self-closing `<Record .../>` element (heart rate, HRV SDNN, blood oxygen,
# respiratory rate, steps, energy, resting/walking heart rate, VO2 max, and
# `SleepAnalysis` category records), plus `<Workout .../>` summaries. The file
# can be hundreds of MB, so it is streamed line by line rather than loaded whole.
# Raw accelerometer and the ECG voltage trace are NOT inside export.xml -- the
# ECG comes as a separate per-recording CSV (see [readAppleECG()]).

# Extract one XML attribute from each of `lines` (NA where absent). Vectorised.
.apple_attr <- function(lines, name) {
  out <- rep(NA_character_, length(lines))
  hit <- grepl(sprintf(' %s="', name), lines, fixed = TRUE)
  if (any(hit)) {
    out[hit] <- sub(sprintf('.* %s="([^"]*)".*', name), "\\1", lines[hit])
  }
  out
}

# Apple timestamps look like "2023-05-01 07:14:22 -0800".
.apple_time <- function(x, tz) {
  as.POSIXct(x, format = "%Y-%m-%d %H:%M:%S %z", tz = tz)
}

.apple_parse_records <- function(lines) {
  data.frame(
    type      = sub("^HK[A-Za-z]*TypeIdentifier", "", .apple_attr(lines, "type")),
    source    = .apple_attr(lines, "sourceName"),
    unit      = .apple_attr(lines, "unit"),
    startDate = .apple_attr(lines, "startDate"),
    endDate   = .apple_attr(lines, "endDate"),
    value     = .apple_attr(lines, "value"),
    stringsAsFactors = FALSE
  )
}

.apple_parse_workouts <- function(lines) {
  data.frame(
    activity    = sub("^HKWorkoutActivityType", "", .apple_attr(lines, "workoutActivityType")),
    duration    = suppressWarnings(as.numeric(.apple_attr(lines, "duration"))),
    duration_unit = .apple_attr(lines, "durationUnit"),
    distance    = suppressWarnings(as.numeric(.apple_attr(lines, "totalDistance"))),
    energy_kcal = suppressWarnings(as.numeric(.apple_attr(lines, "totalEnergyBurned"))),
    startDate   = .apple_attr(lines, "startDate"),
    endDate     = .apple_attr(lines, "endDate"),
    stringsAsFactors = FALSE
  )
}

#' Read an Apple Health export
#'
#' Parses an Apple Health `export.xml` into a tidy set of records and workout
#' summaries. Every sample Apple stores as a `<Record>` -- heart rate, heart-rate
#' variability (`HeartRateVariabilitySDNN`), blood oxygen (`OxygenSaturation`),
#' respiratory rate, step count, active/basal energy, resting and walking heart
#' rate, VO2 max, and `SleepAnalysis` sleep stages -- becomes one row; `<Workout>`
#' elements become the `workouts` table. The reader streams the file, so multi-
#' hundred-MB exports are handled without loading the whole document into memory.
#'
#' The Apple type prefix (`HKQuantityTypeIdentifier` / `HKCategoryTypeIdentifier`)
#' is stripped, so `type` reads e.g. `"HeartRate"`, `"OxygenSaturation"`,
#' `"SleepAnalysis"`. Numeric samples are parsed into `value_num`; category
#' samples (sleep stages) keep their (prefix-stripped) label in `value`.
#'
#' @param path Path to the Apple Health `export.xml`.
#' @param types Optional character vector of (prefix-stripped) record types to
#'   keep; `NULL` (default) keeps all.
#' @param tz Time zone for the parsed timestamps (default `"UTC"`).
#' @return An `apple_health` object: a list with `records` (a data frame with
#'   `type`, `source`, `unit`, `start`, `end`, `value`, `value_num`), `workouts`
#'   (or `NULL`), `path` and `tz`.
#' @seealso [appleHealthSeries()], [appleHealthTypes()], [appleHealthExperiment()],
#'   [readAppleECG()]
#' @references Apple Inc. HealthKit data types and the Health app XML export.
#' @export
#' @examples
#' \dontrun{
#' ah <- readAppleHealth("apple_health_export/export.xml", tz = "Asia/Tokyo")
#' appleHealthTypes(ah)
#' hr <- appleHealthSeries(ah, "HeartRate")
#' }
readAppleHealth <- function(path, types = NULL, tz = "UTC") {
  if (!is.character(path) || length(path) != 1L || !nzchar(path) || !file.exists(path)) {
    stop("Apple Health export not found: ", path, call. = FALSE)
  }
  con <- file(path, "r", encoding = "UTF-8")
  on.exit(close(con))

  rec_parts <- list()
  wk_parts <- list()
  block <- 100000L
  repeat {
    lines <- readLines(con, n = block, warn = FALSE)
    if (!length(lines)) break
    rl <- lines[grepl("<Record ", lines, fixed = TRUE)]
    if (length(rl)) rec_parts[[length(rec_parts) + 1L]] <- .apple_parse_records(rl)
    wl <- lines[grepl("<Workout ", lines, fixed = TRUE)]
    if (length(wl)) wk_parts[[length(wk_parts) + 1L]] <- .apple_parse_workouts(wl)
  }

  if (!length(rec_parts)) {
    stop("No <Record> elements found; is this an Apple Health export.xml? ", path,
         call. = FALSE)
  }
  df <- do.call(rbind, rec_parts)

  df$value_num <- suppressWarnings(as.numeric(df$value))
  # Category records (sleep stages) carry a string value like
  # "HKCategoryValueSleepAnalysisAsleepCore" -> strip "HKCategoryValue" and a
  # leading copy of the (already prefix-stripped) type name, leaving "AsleepCore".
  is_cat <- is.na(df$value_num) & !is.na(df$value) & nzchar(df$value)
  if (any(is_cat)) {
    v <- sub("^HKCategoryValue", "", df$value[is_cat])
    ty <- df$type[is_cat]
    v <- ifelse(startsWith(v, ty), substring(v, nchar(ty) + 1L), v)
    df$value[is_cat] <- v
  }

  df$start <- .apple_time(df$startDate, tz)
  df$end   <- .apple_time(df$endDate, tz)

  if (!is.null(types)) {
    df <- df[df$type %in% types, , drop = FALSE]
    if (!nrow(df)) warning("No records match `types`: ", paste(types, collapse = ", "),
                           call. = FALSE)
  }
  df <- df[order(df$start), c("type", "source", "unit", "start", "end",
                              "value", "value_num")]
  rownames(df) <- NULL

  workouts <- if (length(wk_parts)) {
    w <- do.call(rbind, wk_parts)
    w$start <- .apple_time(w$startDate, tz)
    w$end   <- .apple_time(w$endDate, tz)
    w[order(w$start), c("activity", "duration", "duration_unit", "distance",
                        "energy_kcal", "start", "end")]
  } else NULL

  structure(list(records = df, workouts = workouts, path = path, tz = tz),
            class = "apple_health")
}

#' @export
print.apple_health <- function(x, ...) {
  n <- nrow(x$records)
  cat("<apple_health>", n, "records",
      if (!is.null(x$workouts)) paste0(", ", nrow(x$workouts), " workouts") else "", "\n")
  if (n) {
    rng <- range(x$records$start, na.rm = TRUE)
    cat("  span:", format(rng[1]), "->", format(rng[2]), "\n")
    tt <- sort(table(x$records$type), decreasing = TRUE)
    cat("  types (top):",
        paste(sprintf("%s(%d)", names(tt), tt)[seq_len(min(6L, length(tt)))],
              collapse = ", "), "\n")
  }
  invisible(x)
}

#' Summarise the record types in an Apple Health export
#'
#' @param x An `apple_health` object from [readAppleHealth()].
#' @return A data frame with one row per `type`: `n`, `unit`, and the time `from`/`to`.
#' @seealso [readAppleHealth()], [appleHealthSeries()]
#' @export
appleHealthTypes <- function(x) {
  stopifnot(inherits(x, "apple_health"))
  r <- x$records
  types <- sort(unique(r$type))
  do.call(rbind, lapply(types, function(ty) {
    sub <- r[r$type == ty, , drop = FALSE]
    data.frame(type = ty, n = nrow(sub),
               unit = sub$unit[which(!is.na(sub$unit))[1]],
               from = min(sub$start, na.rm = TRUE),
               to = max(sub$end, na.rm = TRUE), stringsAsFactors = FALSE)
  }))
}

#' Extract one modality's samples from an Apple Health export
#'
#' @param x An `apple_health` object from [readAppleHealth()].
#' @param type A (prefix-stripped) record type, e.g. `"HeartRate"`,
#'   `"HeartRateVariabilitySDNN"`, `"OxygenSaturation"`, `"SleepAnalysis"`.
#' @return A data frame of that type's records (`start`, `end`, `value`,
#'   `value_num`, `unit`, `source`), time-ordered.
#' @seealso [appleHealthTypes()], [appleHealthExperiment()]
#' @export
appleHealthSeries <- function(x, type) {
  stopifnot(inherits(x, "apple_health"))
  if (!is.character(type) || length(type) != 1L) {
    stop("`type` must be a single record-type string.", call. = FALSE)
  }
  sub <- x$records[x$records$type == type, , drop = FALSE]
  if (!nrow(sub)) {
    stop("No records of type '", type, "'. See appleHealthTypes(x) for what is present.",
         call. = FALSE)
  }
  sub[, c("start", "end", "value", "value_num", "unit", "source")]
}

#' Build a PhysioExperiment from one numeric Apple Health modality
#'
#' Apple Health samples are irregularly spaced, so the returned experiment is
#' event-like: a single channel holding the values, `samplingRate` `NA`, and the
#' per-sample timestamps stored in `metadata(pe)$times`.
#'
#' @param x An `apple_health` object from [readAppleHealth()].
#' @param type A numeric record type (e.g. `"HeartRate"`, `"OxygenSaturation"`).
#' @return A `PhysioExperiment` with one channel of the modality's values.
#' @seealso [appleHealthSeries()]
#' @export
appleHealthExperiment <- function(x, type) {
  sub <- appleHealthSeries(x, type)
  v <- sub$value_num
  if (all(is.na(v))) {
    stop("Type '", type, "' is not numeric; use appleHealthSeries() instead.",
         call. = FALSE)
  }
  m <- matrix(v, ncol = 1, dimnames = list(NULL, type))
  PhysioExperiment(
    assays = SimpleList(raw = m),
    colData = DataFrame(label = type, unit = sub$unit[which(!is.na(sub$unit))[1]]),
    metadata = list(source_device = "Apple Health", times = sub$start),
    samplingRate = NA_real_)
}
