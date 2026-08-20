library(PhysioDevices)
library(testthat)

make_googlefit <- function() {
  d <- tempfile("gfit_"); dir.create(d)
  ad <- file.path(d, "All Data"); dir.create(ad)
  writeLines(paste0('{"Data Source":"x","Data Points":[',
    '{"fitValue":[{"value":{"fpVal":62.0}}],"startTimeNanos":"1683007200000000000","endTimeNanos":"1683007200000000000"},',
    '{"fitValue":[{"value":{"fpVal":68.0}}],"startTimeNanos":"1683007260000000000","endTimeNanos":"1683007260000000000"}]}'),
    file.path(ad, "derived_com.google.heart_rate.bpm_com.google.android.gms.json"))
  writeLines(paste0('{"Data Source":"x","Data Points":[',
    '{"fitValue":[{"value":{"intVal":120}}],"startTimeNanos":"1683000000000000000","endTimeNanos":"1683000060000000000"}]}'),
    file.path(ad, "derived_com.google.step_count.delta_com.google.android.gms.json"))
  dm <- file.path(d, "Daily activity metrics"); dir.create(dm)
  writeLines(c("Date,Step count,Calories (kcal),Distance (m),Average heart rate (bpm),Max heart rate (bpm),Min heart rate (bpm)",
               "2023-05-01,8500,320.5,6200,64,110,52"),
             file.path(dm, "2023-05-01.csv"))
  d
}

test_that("readGoogleFit reads granular JSON points and daily CSV", {
  skip_if_not_installed("jsonlite")
  gf <- readGoogleFit(make_googlefit(), tz = "UTC")
  expect_s3_class(gf, "google_fit")
  expect_equal(gf$heart_rate$bpm, c(62, 68))                    # named bpm, like Fitbit
  expect_equal(as.numeric(gf$heart_rate$time[1]), 1683007200)   # nanos decoded
  expect_equal(gf$steps$value, 120)
  expect_equal(gf$daily$steps, 8500)
  expect_equal(gf$daily$hr_avg, 64)
})

make_healthconnect <- function() {
  d <- tempfile("hc_"); dir.create(d)
  writeLines(c("time,beatsPerMinute", "2023-05-01T07:00:00Z,62", "2023-05-01T07:01:00Z,68"),
             file.path(d, "HeartRate.csv"))
  writeLines(c("time,percentage", "2023-05-01T07:00:00Z,97"),
             file.path(d, "OxygenSaturation.csv"))
  writeLines(c("startTime,endTime,count", "2023-05-01T00:00:00Z,2023-05-01T00:01:00Z,120"),
             file.path(d, "Steps.csv"))
  writeLines(c("startTime,endTime,stage",
               "2023-05-01T23:00:00Z,2023-05-02T00:00:00Z,STAGE_TYPE_LIGHT",
               "2023-05-02T00:00:00Z,2023-05-02T00:30:00Z,STAGE_TYPE_DEEP"),
             file.path(d, "SleepSession.csv"))
  d
}

test_that("readHealthConnect parses per-type CSVs incl. sleep stages", {
  hc <- readHealthConnect(make_healthconnect(), tz = "UTC")
  expect_s3_class(hc, "health_connect")
  expect_equal(hc$heart_rate$bpm, c(62, 68))
  expect_equal(hc$spo2$value, 97)
  expect_equal(hc$steps$value, 120)
  expect_equal(hc$sleep$stage, c("light", "deep"))       # STAGE_TYPE_ stripped, lowercased
  # ISO 'Z' timestamp parsed
  expect_equal(as.numeric(hc$heart_rate$time[1]),
               as.numeric(as.POSIXct("2023-05-01 07:00:00", tz = "UTC")))
})

test_that("Health Connect / Google Fit feed the shared analysis layer", {
  skip_if_not_installed("PhysioWearable")
  hc <- readHealthConnect(make_healthconnect())
  m <- PhysioWearable::spo2Metrics(hc$spo2$value)
  expect_equal(m$mean, 97)
  s <- PhysioWearable::summarizeSleepStages(
    hc$sleep, asleep_levels = c("light", "deep", "rem"), wake_levels = "awake",
    stage_cols = c(deep = "deep"))
  expect_equal(s$tst_min, 90)                            # 60 (light) + 30 (deep) min
  expect_equal(s$deep_min, 30)
})

test_that(".iso_time is offset-aware (fixes the timezone bug)", {
  # a "Z" instant under a non-UTC tz keeps the correct absolute time
  t <- PhysioDevices:::.iso_time("2023-05-01T07:00:00Z", tz = "Asia/Tokyo")
  expect_equal(as.numeric(t), as.numeric(as.POSIXct("2023-05-01 07:00:00", tz = "UTC")))
  # a numeric offset is honoured, not silently dropped
  t2 <- PhysioDevices:::.iso_time("2023-05-01T07:00:00+09:00", tz = "UTC")
  expect_equal(as.numeric(t2), as.numeric(as.POSIXct("2023-04-30 22:00:00", tz = "UTC")))
  # a naive timestamp is wall-clock in tz
  t3 <- PhysioDevices:::.iso_time("2023-05-01 07:00:00", tz = "UTC")
  expect_equal(as.numeric(t3), as.numeric(as.POSIXct("2023-05-01 07:00:00", tz = "UTC")))
})

test_that("readGoogleFit tolerates an empty fitValue without aborting", {
  skip_if_not_installed("jsonlite")
  d <- tempfile("gf2_"); dir.create(d); ad <- file.path(d, "All Data"); dir.create(ad)
  writeLines(paste0('{"Data Points":[',
    '{"fitValue":[{"value":{"fpVal":62.0}}],"startTimeNanos":"1683007200000000000"},',
    '{"fitValue":[],"startTimeNanos":"1683007260000000000"}]}'),
    file.path(ad, "derived_com.google.heart_rate.bpm_x.json"))
  gf <- readGoogleFit(d)
  expect_equal(gf$heart_rate$bpm, c(62, NA))   # second point NA, not a crash
})

test_that("readHealthConnect routes HRV separately and skips unknown types", {
  d <- tempfile("hc2_"); dir.create(d)
  writeLines(c("time,beatsPerMinute", "2023-05-01T07:00:00Z,60"), file.path(d, "HeartRate.csv"))
  writeLines(c("time,rmssd", "2023-05-01T07:00:00Z,42"),
             file.path(d, "HeartRateVariabilityRmssd.csv"))
  writeLines(c("time,systolic,diastolic", "2023-05-01T07:00:00Z,120,80"),
             file.path(d, "BloodPressure.csv"))
  hc <- suppressWarnings(readHealthConnect(d, tz = "UTC"))
  expect_equal(hc$heart_rate$bpm, 60)          # HRV not mixed into heart rate
  expect_false(is.null(hc$hrv))                # HRV is its own modality
  expect_null(hc$bloodpressure)                # unknown type not ingested
  expect_warning(readHealthConnect(d), "unknown record type")
})

test_that("summarizeSleepStages default wake_levels matches lowercase labels", {
  skip_if_not_installed("PhysioWearable")
  t0 <- as.POSIXct("2023-05-01 23:00:00", tz = "UTC")
  stages <- data.frame(start = t0 + c(0, 3600, 3720),
                       end   = t0 + c(3600, 3720, 7200),
                       stage = c("light", "awake", "deep"))   # lowercase (HC/Fitbit style)
  s <- PhysioWearable::summarizeSleepStages(stages, asleep_levels = c("light", "deep", "rem"))
  expect_equal(s$waso_min, 2)                  # "awake" counted despite the default "Awake"
})

test_that("error handling for empty inputs", {
  expect_error(readHealthConnect(tempfile()), "not found")
  empty <- tempfile("e_"); dir.create(empty)
  expect_error(readHealthConnect(empty), "No .csv")
  skip_if_not_installed("jsonlite")
  expect_error(readGoogleFit(tempfile()), "not found")
})
