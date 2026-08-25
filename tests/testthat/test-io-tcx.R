library(PhysioDevices)
library(testthat)

make_tcx <- function() {
  f <- tempfile(fileext = ".tcx")
  writeLines(c(
    '<?xml version="1.0"?>',
    '<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2"',
    ' xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2">',
    ' <Activities><Activity Sport="Running"><Lap><Track>',
    '  <Trackpoint><Time>2023-05-01T07:00:00Z</Time>',
    '   <Position><LatitudeDegrees>35.60</LatitudeDegrees><LongitudeDegrees>139.70</LongitudeDegrees></Position>',
    '   <AltitudeMeters>10</AltitudeMeters><DistanceMeters>0</DistanceMeters>',
    '   <HeartRateBpm><Value>120</Value></HeartRateBpm>',
    '   <Extensions><ns3:TPX><ns3:Speed>2.5</ns3:Speed><ns3:RunCadence>85</ns3:RunCadence></ns3:TPX></Extensions></Trackpoint>',
    '  <Trackpoint><Time>2023-05-01T07:00:01Z</Time>',
    '   <Position><LatitudeDegrees>35.61</LatitudeDegrees><LongitudeDegrees>139.71</LongitudeDegrees></Position>',
    '   <AltitudeMeters>11</AltitudeMeters><DistanceMeters>2.5</DistanceMeters>',
    '   <HeartRateBpm><Value>122</Value></HeartRateBpm></Trackpoint>',
    ' </Track></Lap></Activity></Activities></TrainingCenterDatabase>'
  ), f)
  f
}

test_that("readTCX parses trackpoints across namespaces", {
  skip_if_not_installed("xml2")
  tp <- readTCX(make_tcx(), tz = "UTC")
  expect_s3_class(tp, "data.frame")
  expect_equal(nrow(tp), 2L)
  expect_equal(tp$hr, c(120, 122))                 # HeartRateBpm/Value
  expect_equal(tp$lat, c(35.60, 35.61))
  expect_equal(tp$distance_m, c(0, 2.5))
  expect_equal(tp$speed[1], 2.5)                   # ns3: extension read via local-name()
  expect_equal(attr(tp, "sport"), "Running")
  expect_false(is.unsorted(tp$time))
})

make_gpx <- function() {
  f <- tempfile(fileext = ".gpx")
  writeLines(c(
    '<?xml version="1.0"?>',
    '<gpx xmlns="http://www.topografix.com/GPX/1/1"',
    ' xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1">',
    ' <trk><trkseg>',
    '  <trkpt lat="35.60" lon="139.70"><ele>10</ele><time>2023-05-01T07:00:00Z</time>',
    '   <extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>120</gpxtpx:hr><gpxtpx:cad>85</gpxtpx:cad>',
    '   </gpxtpx:TrackPointExtension></extensions></trkpt>',
    '  <trkpt lat="35.61" lon="139.71"><ele>11</ele><time>2023-05-01T07:00:01Z</time></trkpt>',
    ' </trkseg></trk></gpx>'
  ), f)
  f
}

test_that("readGPX parses trkpt attributes and extensions", {
  skip_if_not_installed("xml2")
  tp <- readGPX(make_gpx(), tz = "UTC")
  expect_equal(nrow(tp), 2L)
  expect_equal(tp$lat, c(35.60, 35.61))            # from the lat attribute
  expect_equal(tp$altitude_m, c(10, 11))
  expect_equal(tp$hr, c(120, NA))                  # 2nd point has no HR
  expect_equal(as.numeric(tp$time[1]),
               as.numeric(as.POSIXct("2023-05-01 07:00:00", tz = "UTC")))
})

test_that("error handling for missing / empty files", {
  skip_if_not_installed("xml2")
  expect_error(readTCX(tempfile(fileext = ".tcx")), "not found")
  empty <- tempfile(fileext = ".gpx"); writeLines("<gpx></gpx>", empty)
  expect_error(readGPX(empty), "No <trkpt>")
})
