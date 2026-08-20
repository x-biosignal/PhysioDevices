# Workout / GPS readers: TCX (Garmin Training Center XML) and GPX (GPS Exchange).
#
# These XML formats are the common export from Garmin Connect, Strava, Apple
# Health workouts, Google Fit activities and most GPS watches, so one pair of
# readers covers workout + route data across vendors (the practical path for
# Garmin, whose raw binary .fit needs the GitHub-only FITfileR package). Each
# trackpoint's time, position, altitude, distance, heart rate and cadence/speed
# are returned as a tidy data frame. XPath uses local-name() to ignore the many
# namespace prefixes (ns3:, gpxtpx:, ...). Uses .iso_time() from io-googlefit.R.

.need_xml2 <- function() {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    stop("The 'xml2' package is required to read TCX/GPX files. ",
         "Install it with: install.packages('xml2')", call. = FALSE)
  }
}

# text of the first descendant element with the given local name (NA if absent)
.xml_child_text <- function(node, local) {
  n <- xml2::xml_find_first(node, sprintf(".//*[local-name()='%s']", local))
  if (inherits(n, "xml_missing")) NA_character_ else xml2::xml_text(n)
}

#' Read a TCX (Garmin Training Center) workout file
#'
#' Parses the trackpoints of a `.tcx` workout (the common Garmin Connect / Strava
#' export) into a tidy data frame: time, position, altitude, distance, heart rate
#' and cadence/speed where present.
#'
#' @param path Path to a `.tcx` file.
#' @param tz Time zone for the parsed timestamps (default `"UTC"`).
#' @return A data frame of trackpoints (`time`, `lat`, `lon`, `altitude_m`,
#'   `distance_m`, `hr`, `cadence`, `speed`), time-ordered, with the activity
#'   `sport` in `attr(, "sport")`.
#' @seealso [readGPX()], [readFitbit()]
#' @references Garmin Training Center XML (TCX) schema.
#' @export
#' @examples
#' \dontrun{
#' tp <- readTCX("run.tcx")
#' plot(tp$lon, tp$lat)     # the route
#' }
readTCX <- function(path, tz = "UTC") {
  .need_xml2()
  if (!is.character(path) || length(path) != 1L || !nzchar(path) || !file.exists(path)) {
    stop("TCX file not found: ", path, call. = FALSE)
  }
  doc <- xml2::read_xml(path)
  tps <- xml2::xml_find_all(doc, ".//*[local-name()='Trackpoint']")
  if (!length(tps)) stop("No <Trackpoint> elements in TCX: ", path, call. = FALSE)

  num <- function(local) as.numeric(vapply(tps, .xml_child_text, "", local))
  # cadence is <Cadence> (cycling) or <ns3:RunCadence> (running) -> match either
  cad <- as.numeric(vapply(tps, function(n) {
    x <- xml2::xml_find_first(n, ".//*[contains(local-name(),'adence')]")
    if (inherits(x, "xml_missing")) NA_character_ else xml2::xml_text(x)
  }, ""))
  df <- data.frame(
    time       = .iso_time(vapply(tps, .xml_child_text, "", "Time"), tz),
    lat        = num("LatitudeDegrees"),
    lon        = num("LongitudeDegrees"),
    altitude_m = num("AltitudeMeters"),
    distance_m = num("DistanceMeters"),
    hr         = num("HeartRateBpm"),      # <HeartRateBpm><Value>..</Value></>
    cadence    = cad,
    speed      = num("Speed"),             # Extensions/TPX/Speed
    stringsAsFactors = FALSE)
  df <- df[order(df$time), ]
  rownames(df) <- NULL
  sport <- xml2::xml_attr(xml2::xml_find_first(doc, ".//*[local-name()='Activity']"), "Sport")
  attr(df, "sport") <- sport
  attr(df, "source_file") <- basename(path)
  df
}

#' Read a GPX (GPS Exchange) track file
#'
#' Parses the track points of a `.gpx` file (a widely shared GPS/workout export)
#' into a tidy data frame: time, position, altitude, and heart rate / cadence
#' when the Garmin TrackPointExtension is present.
#'
#' @param path Path to a `.gpx` file.
#' @param tz Time zone for the parsed timestamps (default `"UTC"`).
#' @return A data frame of track points (`time`, `lat`, `lon`, `altitude_m`,
#'   `hr`, `cadence`), time-ordered.
#' @seealso [readTCX()]
#' @references GPX 1.1 schema; Garmin TrackPointExtension.
#' @export
#' @examples
#' \dontrun{
#' tp <- readGPX("ride.gpx")
#' }
readGPX <- function(path, tz = "UTC") {
  .need_xml2()
  if (!is.character(path) || length(path) != 1L || !nzchar(path) || !file.exists(path)) {
    stop("GPX file not found: ", path, call. = FALSE)
  }
  doc <- xml2::read_xml(path)
  tps <- xml2::xml_find_all(doc, ".//*[local-name()='trkpt']")
  if (!length(tps)) stop("No <trkpt> elements in GPX: ", path, call. = FALSE)

  df <- data.frame(
    time       = .iso_time(vapply(tps, .xml_child_text, "", "time"), tz),
    lat        = as.numeric(xml2::xml_attr(tps, "lat")),
    lon        = as.numeric(xml2::xml_attr(tps, "lon")),
    altitude_m = as.numeric(vapply(tps, .xml_child_text, "", "ele")),
    hr         = as.numeric(vapply(tps, .xml_child_text, "", "hr")),
    cadence    = as.numeric(vapply(tps, .xml_child_text, "", "cad")),
    stringsAsFactors = FALSE)
  df <- df[order(df$time), ]
  rownames(df) <- NULL
  attr(df, "source_file") <- basename(path)
  df
}
