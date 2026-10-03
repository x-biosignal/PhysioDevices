library(PhysioDevices)
library(testthat)

# Build a synthetic Fitbit archive directory with the documented file shapes.
make_fitbit_archive <- function() {
  d <- file.path(tempfile("fitbit_"))
  dir.create(d)
  writeLines(paste0("[",
    '{"dateTime":"05/01/23 07:00:00","value":{"bpm":62,"confidence":2}},',
    '{"dateTime":"05/01/23 07:00:15","value":{"bpm":66,"confidence":3}},',
    '{"dateTime":"05/01/23 07:00:30","value":{"bpm":70,"confidence":3}}]'),
    file.path(d, "heart_rate-2023-05-01.json"))
  writeLines('[{"dateTime":"05/01/23 00:00:00","value":"0"},{"dateTime":"05/01/23 00:01:00","value":"120"}]',
    file.path(d, "steps-2023-05-01.json"))
  writeLines('[{"dateTime":"2023-05-01","value":{"avg":95.5,"min":92,"max":98}}]',
    file.path(d, "spo2-2023-05-01.json"))
  writeLines('[{"dateTime":"2023-05-01","value":{"date":"2023-05-01","value":58,"error":1.2}}]',
    file.path(d, "resting_heart_rate-2023-05-01.json"))
  writeLines(paste0('[{"logId":123,"startTime":"2023-05-01T23:00:00.000",',
    '"endTime":"2023-05-02T06:30:00.000","efficiency":92,"minutesAsleep":400,',
    '"minutesAwake":20,"timeInBed":450,"levels":{"data":[',
    '{"dateTime":"2023-05-01T23:00:00.000","level":"wake","seconds":300},',
    '{"dateTime":"2023-05-01T23:05:00.000","level":"light","seconds":3600},',
    '{"dateTime":"2023-05-02T00:05:00.000","level":"deep","seconds":1800},',
    '{"dateTime":"2023-05-02T00:35:00.000","level":"rem","seconds":1200}]}}]'),
    file.path(d, "sleep-2023-05-01.json"))
  d
}

test_that("readFitbit parses the core modalities from an archive directory", {
  skip_if_not_installed("jsonlite")
  fb <- readFitbit(make_fitbit_archive(), tz = "UTC")
  expect_s3_class(fb, "fitbit")

  expect_equal(fb$heart_rate$bpm, c(62, 66, 70))
  expect_equal(as.numeric(fb$heart_rate$time[1]),
               as.numeric(as.POSIXct("2023-05-01 07:00:00", tz = "UTC")))   # US date parsed

  expect_equal(fb$steps$value, c(0, 120))
  expect_equal(fb$spo2$value, 95.5)                       # daily avg
  expect_equal(fb$resting_heart_rate$value, 58)
})

test_that("readFitbit parses sleep stages and Fitbit's own summary", {
  skip_if_not_installed("jsonlite")
  fb <- readFitbit(make_fitbit_archive())
  expect_equal(nrow(fb$sleep), 4L)
  expect_equal(fb$sleep$stage, c("wake", "light", "deep", "rem"))
  # first interval: 23:00:00 for 300 s -> ends 23:05:00
  expect_equal(as.numeric(difftime(fb$sleep$end[1], fb$sleep$start[1], units = "secs")), 300)
  expect_equal(fb$sleep_summary$efficiency, 92)
  expect_equal(fb$sleep_summary$minutes_asleep, 400)
})

test_that("fitbitSeries / what filter / error handling", {
  skip_if_not_installed("jsonlite")
  arch <- make_fitbit_archive()
  fb <- readFitbit(arch, what = c("heart_rate", "spo2"))
  expect_setequal(setdiff(names(fb), c("path", "tz")), c("heart_rate", "spo2"))
  expect_equal(fitbitSeries(fb, "spo2")$value, 95.5)
  expect_error(fitbitSeries(fb, "sleep"), "No modality")

  expect_error(readFitbit(tempfile()), "not found")
  empty <- tempfile("empty_"); dir.create(empty)
  expect_error(readFitbit(empty), "No .json/.csv")
})

test_that("Fitbit sleep stages feed the generic sleep summariser", {
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("PhysioWearable")
  fb <- readFitbit(make_fitbit_archive())
  s <- PhysioWearable::summarizeSleepStages(
    fb$sleep, asleep_levels = c("light", "deep", "rem"), wake_levels = "wake",
    stage_cols = c(light = "light", deep = "deep", rem = "rem"))
  expect_equal(s$tst_min, (3600 + 1800 + 1200) / 60)     # light+deep+rem minutes
})
