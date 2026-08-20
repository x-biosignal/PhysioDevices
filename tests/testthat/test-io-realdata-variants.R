library(testthat)
library(PhysioDevices)

# Regression tests for real-export variants discovered by validating the readers
# against real public samples (Apple: tdda/applehealthdata MIT sample; Fitbit:
# the PMData dataset, CC BY-NC -- not redistributable, so its *structure* is
# reproduced here synthetically). The live validation lives in
# planning/realdata-validation/validate_apple_fitbit.R.

# ---- Fitbit: aggregated Web-API export layout (PMData) ----------------------
# PMData writes one file per modality (heart_rate.json, steps.json, sleep.json)
# with no per-day date suffix. readFitbit must handle this as well as the
# account archive's heart_rate-YYYY-MM-DD.json files.

test_that("readFitbit reads the aggregated single-file (PMData) layout", {
  skip_if_not_installed("jsonlite")
  dir <- file.path(tempfile("fitbit_agg")); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  writeLines(paste0('[',
    '{"dateTime": "2019-11-01 00:00:05", "value": {"bpm": 54, "confidence": 3}},',
    '{"dateTime": "2019-11-01 00:00:10", "value": {"bpm": 52, "confidence": 3}},',
    '{"dateTime": "2019-11-01 00:00:20", "value": {"bpm": 58, "confidence": 2}}]'),
    file.path(dir, "heart_rate.json"))
  writeLines('[{"dateTime": "2019-11-01 00:00:00", "value": "0"}, {"dateTime": "2019-11-01 00:10:00", "value": "12"}]',
    file.path(dir, "steps.json"))
  writeLines(paste0('[{"dateTime": "2019-11-01 00:00:00", "value": ',
    '{"date": "11/01/19", "value": 53.7, "error": 6.8}}]'),
    file.path(dir, "resting_heart_rate.json"))
  writeLines(paste0('[{"logId": 111, "dateOfSleep": "2019-11-02", ',
    '"startTime": "2019-11-02 00:09:30", "endTime": "2019-11-02T07:19:30.000", ',
    '"efficiency": 97, "minutesAsleep": 378, "minutesAwake": 52, "timeInBed": 430, ',
    '"type": "stages", "levels": {"data": [',
    '{"dateTime": "2019-11-02T00:09:30.000", "level": "wake", "seconds": 30},',
    '{"dateTime": "2019-11-02T00:10:00.000", "level": "light", "seconds": 3570},',
    '{"dateTime": "2019-11-02T01:09:30.000", "level": "deep", "seconds": 1140}]}}]'),
    file.path(dir, "sleep.json"))
  # a same-prefix CSV that must NOT be mistaken for the sleep-stage JSON
  writeLines(c("sleep_log_entry_id,timestamp,overall_score", "111,2019-11-02,80"),
    file.path(dir, "sleep_score.csv"))

  fb <- readFitbit(dir, tz = "UTC")
  expect_setequal(setdiff(names(fb), c("path", "tz", "sleep_summary")),
                  c("heart_rate", "steps", "resting_heart_rate", "sleep"))
  expect_equal(fb$heart_rate$bpm, c(54, 52, 58))          # value.bpm pulled
  expect_equal(sum(fb$steps$value), 12)                   # value string -> numeric
  expect_equal(fb$resting_heart_rate$value, 53.7)         # not merged into heart_rate
  expect_setequal(fb$sleep$stage, c("wake", "light", "deep"))
  expect_equal(fb$sleep$end[1], fb$sleep$start[1] + 30)   # stage duration from seconds
  expect_equal(fb$sleep_summary$efficiency, 97)
})

test_that("readFitbit still separates resting_heart_rate from heart_rate", {
  skip_if_not_installed("jsonlite")
  dir <- file.path(tempfile("fitbit_rhr")); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  writeLines('[{"dateTime": "2019-11-01 00:00:05", "value": {"bpm": 60, "confidence": 3}}]',
    file.path(dir, "heart_rate.json"))
  writeLines('[{"dateTime": "2019-11-01 00:00:00", "value": {"value": 55}}]',
    file.path(dir, "resting_heart_rate.json"))
  fb <- readFitbit(dir, tz = "UTC")
  expect_equal(fb$heart_rate$bpm, 60)                     # resting file not swept in
  expect_equal(fb$resting_heart_rate$value, 55)
})

# ---- Apple Health: offset-bearing timestamps (tdda sample structure) --------
# The real sample's records carry a numeric UTC offset ("... +0100"); the reader
# must treat that as an absolute instant, not wall-clock in the requested tz.

test_that("readAppleHealth parses HealthKit records with a UTC offset correctly", {
  skip_if_not_installed("xml2")
  xml <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>\n<HealthData locale="en_GB">\n',
    '<Me HKCharacteristicTypeIdentifierBiologicalSex="HKBiologicalSexMale"/>\n',
    '<Record type="HKQuantityTypeIdentifierStepCount" sourceName="Health" unit="count" ',
    'creationDate="2014-09-21 07:08:47 +0100" startDate="2014-09-13 10:27:54 +0100" ',
    'endDate="2014-09-13 10:27:59 +0100" value="329"/>\n',
    '<Record type="HKQuantityTypeIdentifierStepCount" sourceName="Health" unit="count" ',
    'creationDate="2014-09-21 07:08:47 +0100" startDate="2014-09-13 10:34:09 +0100" ',
    'endDate="2014-09-13 10:34:14 +0100" value="283"/>\n',
    '</HealthData>\n')
  f <- tempfile(fileext = ".xml"); writeLines(xml, f)
  on.exit(unlink(f), add = TRUE)

  utc <- appleHealthSeries(readAppleHealth(f, tz = "UTC"), "StepCount")
  lon <- appleHealthSeries(readAppleHealth(f, tz = "Europe/London"), "StepCount")
  expect_equal(nrow(utc), 2L)
  # 10:27:54 +0100 is the same instant as 09:27:54 UTC / 10:27:54 BST
  expect_equal(format(utc$start[1], tz = "UTC", format = "%H:%M:%S"), "09:27:54")
  expect_equal(format(lon$start[1], tz = "Europe/London", format = "%H:%M:%S"), "10:27:54")
  expect_equal(sum(utc$value_num), 612)                   # type prefix stripped, value numeric
})

# ---- Oura: API v1 and v2 sleep layouts (lildude/oura fixture structure) ------
# v1 wraps records in {sleep:[...]}, phases in hypnogram_5min, HR/HRV as flat
# hr_5min / rmssd_5min arrays (0 = no reading). v2 wraps in {data:[...]}, phases
# in sleep_phase_5_min, HR/HRV nested {interval, items, timestamp}. readOura
# must handle both (real data from either version was previously mis-read).

test_that("readOura reads the API v1 sleep layout (hypnogram + flat hr/rmssd)", {
  skip_if_not_installed("jsonlite")
  f <- tempfile(fileext = ".json")
  writeLines(paste0('{"sleep":[{"summary_date":"2020-01-01",',
    '"bedtime_start":"2020-01-01T23:00:00+00:00","hypnogram_5min":"1123443",',
    '"hr_5min":[55,0,58,60,0,52,54],"rmssd_5min":[40,0,45,50,0,38,42],',
    '"efficiency":94,"total":21600,"duration":23400}]}'), f)
  on.exit(unlink(f), add = TRUE)
  o <- readOura(f, tz = "UTC")
  expect_setequal(setdiff(names(o), c("path", "tz")),
                  c("sleep", "sleep_summary", "heart_rate", "hrv"))
  expect_equal(nrow(o$sleep), 7L)
  expect_setequal(unique(o$sleep$stage), c("deep", "light", "rem", "awake"))
  expect_equal(o$heart_rate$bpm, c(55, NA, 58, 60, NA, 52, 54))   # 0 -> NA
  expect_equal(o$hrv$rmssd, c(40, NA, 45, 50, NA, 38, 42))
  expect_equal(o$sleep_summary$total_sleep_min, 360)             # total / 60
  expect_equal(o$sleep_summary$time_in_bed_min, 390)             # duration / 60
  expect_equal(o$sleep_summary$efficiency, 94)
})

test_that("readOura reads the API v2 sleep layout (sleep_phase + nested hr/hrv)", {
  skip_if_not_installed("jsonlite")
  f <- tempfile(fileext = ".json")
  writeLines(paste0('{"data":[{"day":"2022-07-12","type":"long_sleep",',
    '"bedtime_start":"2022-07-12T01:05:14-07:00","sleep_phase_5_min":"11234",',
    '"heart_rate":{"interval":300,"timestamp":"2022-07-12T01:05:14-07:00",',
    '"items":[54,null,56,52,58]},"hrv":{"interval":300,',
    '"timestamp":"2022-07-12T01:05:14-07:00","items":[40,null,45,50,42]},',
    '"efficiency":84,"time_in_bed":30000,"total_sleep_duration":null}],',
    '"next_token":null}'), f)
  on.exit(unlink(f), add = TRUE)
  o <- readOura(f, tz = "UTC")
  expect_equal(nrow(o$sleep), 5L)
  expect_setequal(unique(o$sleep$stage), c("deep", "light", "rem", "awake"))
  # bedtime 01:05:14 -07:00 == 08:05:14 UTC
  expect_equal(format(o$sleep$start[1], tz = "UTC", format = "%H:%M:%S"), "08:05:14")
  expect_equal(o$heart_rate$bpm, c(54, NA, 56, 52, 58))          # null -> NA
  expect_equal(nrow(o$hrv), 5L)
  expect_true(is.na(o$sleep_summary$total_sleep_min))            # null total_sleep_duration
  expect_equal(o$sleep_summary$time_in_bed_min, 500)            # 30000 / 60
  expect_equal(o$sleep_summary$efficiency, 84)
})

# ---- Google Fit: granular "All Data" JSON (niimpy sampledata structure) ------
# The real Takeout export writes startTimeNanos as an UNQUOTED 19-digit integer
# and fitValue[[1]]$value as {fpVal} (heart rate) or {intVal} (steps) -- the
# earlier fixture only covered the quoted-string form.

test_that("readGoogleFit reads the real granular JSON (unquoted nanos, fpVal/intVal)", {
  skip_if_not_installed("jsonlite")
  d <- file.path(tempfile("gf_gran")); dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  writeLines(paste0('{"Data Source":"raw:com.google.heart_rate.bpm:x",',
    '"Data Points":[',
    '{"fitValue":[{"value":{"fpVal":65}}],"startTimeNanos":1715771743000000000,',
    '"endTimeNanos":1715771744000000000,"dataTypeName":"com.google.heart_rate.bpm"},',
    '{"fitValue":[{"value":{"fpVal":72}}],"startTimeNanos":1715771803000000000}]}'),
    file.path(d, "raw_com.google.heart_rate.bpm_x.json"))
  writeLines(paste0('{"Data Points":[',
    '{"fitValue":[{"value":{"intVal":42}}],"startTimeNanos":1700569269000000000},',
    '{"fitValue":[{"value":{"intVal":13}}],"startTimeNanos":1700569353000000000}]}'),
    file.path(d, "derived_com.google.step_count.delta_x.json"))
  g <- readGoogleFit(d, tz = "UTC")
  expect_equal(g$heart_rate$bpm, c(65, 72))         # fpVal, unquoted nanos
  expect_equal(g$steps$value, c(42, 13))            # intVal
  # 1715771743e9 ns == 2024-05-15 11:15:43 UTC (seconds recovered despite >2^53)
  expect_equal(format(g$heart_rate$time[1], tz = "UTC", format = "%Y-%m-%d %H:%M:%S"),
               "2024-05-15 11:15:43")
})
