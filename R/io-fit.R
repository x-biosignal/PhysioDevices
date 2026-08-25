# Garmin / ANT+ FIT reader.
#
# FIT is the binary format Garmin, Wahoo, Coros and most cycling/running head
# units record. It has no CRAN parser; this delegates to the FITfileR package
# (install from https://grimbough.r-universe.dev) and adapts its `record`
# messages into the same tidy trackpoint data frame as readTCX()/readGPX().

# FIT encodes a missing reading as the base type's maximum (uint8 -> 255,
# uint16 -> 65535). Those must become NA, not impossible 255 bpm / 65535 W
# values -- e.g. a bike ride recorded without a HR strap carries hr = 255 on
# every record, which would otherwise read as a mean HR of 255.
.fit_na <- function(x, sentinel) { x[!is.na(x) & x == sentinel] <- NA_real_; x }

# Adapt a FITfileR record-message data frame into the trackpoint columns.
.fit_track <- function(rec, tz) {
  pick <- function(cands) {
    for (c in cands) if (c %in% names(rec)) return(rec[[c]])
    rep(NA, nrow(rec))
  }
  ts <- pick("timestamp")
  time <- if (inherits(ts, "POSIXct")) ts else .iso_time(as.character(ts), tz)
  df <- data.frame(
    time       = time,
    lat        = as.numeric(pick(c("position_lat", "latitude"))),
    lon        = as.numeric(pick(c("position_long", "longitude"))),
    altitude_m = as.numeric(pick(c("altitude", "enhanced_altitude"))),
    distance_m = as.numeric(pick("distance")),
    hr         = .fit_na(as.numeric(pick("heart_rate")), 255),
    cadence    = .fit_na(as.numeric(pick("cadence")), 255),
    speed      = as.numeric(pick(c("speed", "enhanced_speed"))),
    power      = .fit_na(as.numeric(pick("power")), 65535),
    stringsAsFactors = FALSE)
  df[order(df$time), ]
}

# FITfileR sometimes returns a list of record frames (one per message definition)
# -> bind them on the union of columns.
.fit_bind <- function(rec) {
  if (is.data.frame(rec)) return(rec)
  lst <- rec[vapply(rec, is.data.frame, logical(1))]
  if (!length(lst)) return(NULL)
  cols <- unique(unlist(lapply(lst, names)))
  do.call(rbind, lapply(lst, function(d) {
    for (c in setdiff(cols, names(d))) d[[c]] <- NA
    d[cols]
  }))
}

#' Read a Garmin/ANT+ FIT workout file
#'
#' Reads a `.fit` file (Garmin, Wahoo, Coros, ...) into a tidy trackpoint data
#' frame, in the same shape as [readTCX()] / [readGPX()]. The binary decode is
#' delegated to the FITfileR package (not on CRAN -- install with
#' `install.packages("FITfileR", repos = "https://grimbough.r-universe.dev")`).
#'
#' @param path Path to a `.fit` file.
#' @param tz Time zone for the parsed timestamps (default `"UTC"`).
#' @return A data frame of trackpoints (`time`, `lat`, `lon`, `altitude_m`,
#'   `distance_m`, `hr`, `cadence`, `speed`, `power`), time-ordered.
#' @seealso [readTCX()], [readGPX()]
#' @references Garmin FIT SDK; grimbough/FITfileR.
#' @export
#' @examples
#' \dontrun{
#' tp <- readFIT("activity.fit")
#' }
readFIT <- function(path, tz = "UTC") {
  if (!requireNamespace("FITfileR", quietly = TRUE)) {
    stop("The 'FITfileR' package is required to read .fit files. Install it with: ",
         "install.packages('FITfileR', repos = 'https://grimbough.r-universe.dev')",
         call. = FALSE)
  }
  if (!is.character(path) || length(path) != 1L || !nzchar(path) || !file.exists(path)) {
    stop("FIT file not found: ", path, call. = FALSE)
  }
  ff <- FITfileR::readFitFile(path)
  rec <- .fit_bind(FITfileR::getMessagesByType(ff, "record"))
  if (is.null(rec) || !nrow(rec)) stop("No record messages in FIT file: ", path, call. = FALSE)
  .fit_track(rec, tz)
}
