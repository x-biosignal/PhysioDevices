library(testthat)
library(PhysioDevices)

# Schema-conformance tests for readHealthConnect.
#
# No public real Health Connect export exists (it is on-device Android data with
# no canonical export file), so -- unlike Apple/Fitbit/Oura/Google Fit, which are
# validated against real samples in planning/realdata-validation/ -- these
# fixtures reproduce the *documented* export schema exactly, so the reader is held
# to the real format rather than a convenient synthetic one:
#   * androidx Health Connect record field names (developer.android.com
#     health-and-fitness/health-connect/data-types): HeartRate.beatsPerMinute,
#     OxygenSaturation.percentage, RespiratoryRate.rate,
#     HeartRateVariabilityRmssd.heartRateVariabilityMillis, Steps.count,
#     SleepSessionRecord.StageType (the full 8-value enum).
#   * the MyDataHelps exporter's real CSV layout
#     (support.mydatahelps.org/health-connect-*-records-export-format): PascalCase
#     columns (Time, BeatsPerMinute, StartTime, EndTime, Stage), a leading
#     HealthConnectRecordKey and Metadata* columns, and ISO-8601 timestamps with
#     either a millisecond+offset (2026-03-20T23:26:16.000-04:00) or a UTC Z.

# Writes a directory that mirrors the MyDataHelps Health Connect export layout.
make_hc_schema <- function() {
  d <- tempfile("hc_schema_"); dir.create(d)
  # Heart Rate "samples" file: HealthConnectRecordKey,Time,BeatsPerMinute
  writeLines(c("HealthConnectRecordKey,Time,BeatsPerMinute",
               "k1,2026-03-20T23:26:16.000-04:00,61",
               "k1,2026-03-20T23:27:16.000-04:00,63"),
             file.path(d, "Heart Rate Samples.csv"))
  # HRV: canonical field heartRateVariabilityMillis (PascalCase in the export)
  writeLines(c("HealthConnectRecordKey,Time,HeartRateVariabilityMillis",
               "k2,2026-03-20T23:26:16.000-04:00,44"),
             file.path(d, "Heart Rate Variability Rmssd Records.csv"))
  # Oxygen saturation, with a Metadata* column present to test time/value detection
  writeLines(c("HealthConnectRecordKey,MetadataDeviceModel,Time,Percentage",
               "k3,Pixel Watch,2026-03-20T23:26:16.000-04:00,97"),
             file.path(d, "Oxygen Saturation Records.csv"))
  # Respiratory rate
  writeLines(c("HealthConnectRecordKey,Time,Rate",
               "k4,2026-03-20T23:26:16.000-04:00,15.5"),
             file.path(d, "Respiratory Rate Records.csv"))
  # Steps: interval record (StartTime + EndTime); StartTime is the sample time
  writeLines(c("HealthConnectRecordKey,StartTime,StartZoneOffsetSetAtUpload,EndTime,Count",
               "k5,2026-03-20T00:00:00.000-04:00,-04:00,2026-03-20T00:10:00.000-04:00,240"),
             file.path(d, "Steps Records.csv"))
  # Sleep stages file: HealthConnectRecordKey,StartTime,EndTime,Stage (UTC Z),
  # exercising the full SleepSessionRecord.StageType enum.
  stages <- c("STAGE_TYPE_UNKNOWN", "STAGE_TYPE_AWAKE", "STAGE_TYPE_SLEEPING",
              "STAGE_TYPE_OUT_OF_BED", "STAGE_TYPE_LIGHT", "STAGE_TYPE_DEEP",
              "STAGE_TYPE_REM", "STAGE_TYPE_AWAKE_IN_BED")
  rows <- vapply(seq_along(stages), function(i) sprintf(
    "k6,2026-03-21T0%d:00:00Z,2026-03-21T0%d:30:00Z,%s", i - 1L, i - 1L, stages[i]), "")
  writeLines(c("HealthConnectRecordKey,StartTime,EndTime,Stage", rows),
             file.path(d, "Sleep Stages.csv"))
  d
}

test_that("readHealthConnect reads the documented per-type schema (PascalCase)", {
  hc <- suppressWarnings(readHealthConnect(make_hc_schema(), tz = "UTC"))
  expect_s3_class(hc, "health_connect")
  expect_equal(hc$heart_rate$bpm, c(61, 63))
  expect_equal(hc$spo2$value, 97)
  expect_equal(hc$respiratory_rate$value, 15.5)
  expect_equal(hc$steps$value, 240)
})

test_that("readHealthConnect reads the canonical heartRateVariabilityMillis field", {
  hc <- suppressWarnings(readHealthConnect(make_hc_schema(), tz = "UTC"))
  # the previous heuristic (rmssd|value) missed heartRateVariabilityMillis
  expect_false(is.null(hc$hrv))
  expect_equal(hc$hrv$value, 44)
  expect_null(hc$heart_rate$value)      # HRV kept out of heart rate
})

test_that("readHealthConnect strips the full SleepSessionRecord StageType enum", {
  hc <- suppressWarnings(readHealthConnect(make_hc_schema(), tz = "UTC"))
  expect_setequal(hc$sleep$stage,
                  c("unknown", "awake", "sleeping", "out_of_bed",
                    "light", "deep", "rem", "awake_in_bed"))
  expect_equal(nrow(hc$sleep), 8L)
})

test_that("readHealthConnect parses ms+offset and Z timestamps as absolute instants", {
  hc <- suppressWarnings(readHealthConnect(make_hc_schema(), tz = "UTC"))
  # 2026-03-20T23:26:16.000-04:00 == 2026-03-21 03:26:16 UTC
  expect_equal(format(hc$heart_rate$time[1], tz = "UTC", format = "%Y-%m-%d %H:%M:%S"),
               "2026-03-21 03:26:16")
  # sleep stage StartTime is a UTC Z instant
  expect_equal(format(min(hc$sleep$start), tz = "UTC", format = "%H:%M:%S"), "00:00:00")
})

test_that("readHealthConnect uses StartTime (not EndTime) for interval records", {
  hc <- suppressWarnings(readHealthConnect(make_hc_schema(), tz = "UTC"))
  # Steps StartTime 00:00:00-04:00 == 04:00:00 UTC, not the 00:10 EndTime
  expect_equal(format(hc$steps$time[1], tz = "UTC", format = "%H:%M:%S"), "04:00:00")
})

test_that("readHealthConnect detects time/value past leading Metadata columns", {
  # OxygenSaturation fixture has HealthConnectRecordKey + MetadataDeviceModel first
  hc <- suppressWarnings(readHealthConnect(make_hc_schema(), tz = "UTC"))
  expect_equal(hc$spo2$value, 97)
  expect_equal(format(hc$spo2$time[1], tz = "UTC", format = "%H:%M:%S"), "03:26:16")
})
