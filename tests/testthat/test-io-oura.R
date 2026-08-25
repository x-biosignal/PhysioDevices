library(PhysioDevices)
library(testthat)

make_oura <- function() {
  f <- tempfile(fileext = ".json")
  writeLines(paste0('{"data":[{"day":"2023-05-01",',
    '"bedtime_start":"2023-05-01T23:00:00+00:00","bedtime_end":"2023-05-02T00:00:00+00:00",',
    '"efficiency":90,"total_sleep_duration":3300,"time_in_bed":3600,',
    '"hypnogram_5min":"221133",',
    '"heart_rate":{"interval":300,"timestamp":"2023-05-01T23:00:00+00:00","items":[60,61,62,63,64,65]},',
    '"hrv":{"interval":300,"timestamp":"2023-05-01T23:00:00+00:00","items":[45,46,47,48,49,50]}}]}'), f)
  f
}

test_that("readOura expands the hypnogram and reads HR/HRV series", {
  skip_if_not_installed("jsonlite")
  ou <- readOura(make_oura(), tz = "UTC")
  expect_s3_class(ou, "oura")
  expect_equal(nrow(ou$sleep), 6L)
  expect_equal(ou$sleep$stage, c("light", "light", "deep", "deep", "rem", "rem"))
  # first epoch: 23:00 for 300 s
  expect_equal(as.numeric(difftime(ou$sleep$end[1], ou$sleep$start[1], units = "secs")), 300)
  expect_equal(ou$heart_rate$bpm, 60:65)
  expect_equal(ou$hrv$rmssd, 45:50)
  expect_equal(ou$sleep_summary$efficiency, 90)
  expect_equal(ou$sleep_summary$total_sleep_min, 55)      # 3300 s
})

test_that("Oura sleep stages feed the shared sleep summariser", {
  skip_if_not_installed("jsonlite")
  skip_if_not_installed("PhysioWearable")
  ou <- readOura(make_oura())
  s <- PhysioWearable::summarizeSleepStages(ou$sleep,
    asleep_levels = c("light", "deep", "rem"),
    stage_cols = c(deep = "deep", rem = "rem"))
  expect_equal(s$tst_min, 30)                             # all 6 epochs asleep = 30 min
  expect_equal(s$deep_min, 10)
})

test_that("Oura tolerates null HR items and errors on a non-Oura file", {
  skip_if_not_installed("jsonlite")
  f <- tempfile(fileext = ".json")
  writeLines(paste0('{"data":[{"day":"2023-05-02","bedtime_start":"2023-05-02T23:00:00+00:00",',
    '"hypnogram_5min":"12","heart_rate":{"interval":300,"items":[60,null,62]}}]}'), f)
  ou <- readOura(f)
  expect_equal(ou$heart_rate$bpm, c(60, NA, 62))          # null kept as NA (length preserved)
  bogus <- tempfile(fileext = ".json"); writeLines('{"foo":1}', bogus)
  expect_error(readOura(bogus), "No recognised Oura")
})
