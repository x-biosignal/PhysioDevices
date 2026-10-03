library(PhysioDevices)
library(testthat)

# A minimal but realistic Apple Health export.xml (one <Record> per line, plus a
# workout), written to a temp file.
make_apple_export <- function() {
  f <- tempfile(fileext = ".xml")
  writeLines(c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<HealthData locale="en_US">',
    ' <Record type="HKQuantityTypeIdentifierHeartRate" sourceName="Apple Watch" unit="count/min" startDate="2023-05-01 07:00:00 -0800" endDate="2023-05-01 07:00:00 -0800" value="62"/>',
    ' <Record type="HKQuantityTypeIdentifierHeartRate" sourceName="Apple Watch" unit="count/min" startDate="2023-05-01 07:01:00 -0800" endDate="2023-05-01 07:01:00 -0800" value="68"/>',
    ' <Record type="HKQuantityTypeIdentifierHeartRateVariabilitySDNN" sourceName="Apple Watch" unit="ms" startDate="2023-05-01 07:02:00 -0800" endDate="2023-05-01 07:02:00 -0800" value="45.2"/>',
    ' <Record type="HKQuantityTypeIdentifierOxygenSaturation" sourceName="Apple Watch" unit="%" startDate="2023-05-01 07:03:00 -0800" endDate="2023-05-01 07:03:00 -0800" value="0.97"/>',
    ' <Record type="HKCategoryTypeIdentifierSleepAnalysis" sourceName="Apple Watch" startDate="2023-05-01 23:00:00 -0800" endDate="2023-05-02 02:00:00 -0800" value="HKCategoryValueSleepAnalysisAsleepCore"/>',
    ' <Record type="HKCategoryTypeIdentifierSleepAnalysis" sourceName="Apple Watch" startDate="2023-05-02 02:00:00 -0800" endDate="2023-05-02 02:20:00 -0800" value="HKCategoryValueSleepAnalysisAwake"/>',
    ' <Workout workoutActivityType="HKWorkoutActivityTypeRunning" duration="30.5" durationUnit="min" totalDistance="5.2" totalDistanceUnit="km" totalEnergyBurned="320" startDate="2023-05-01 18:00:00 -0800" endDate="2023-05-01 18:30:30 -0800"/>',
    '</HealthData>'
  ), f)
  f
}

test_that("readAppleHealth parses records, strips prefixes, and parses dates", {
  ah <- readAppleHealth(make_apple_export(), tz = "UTC")
  expect_s3_class(ah, "apple_health")
  expect_equal(nrow(ah$records), 6L)
  expect_true(all(c("HeartRate", "HeartRateVariabilitySDNN", "OxygenSaturation",
                    "SleepAnalysis") %in% ah$records$type))     # prefix stripped
  # numeric values parsed; SpO2 kept as a fraction
  hrv <- ah$records[ah$records$type == "HeartRateVariabilitySDNN", ]
  expect_equal(hrv$value_num, 45.2)
  # sleep category value keeps a (prefix-stripped) label, not a number
  sleep <- ah$records[ah$records$type == "SleepAnalysis", ]
  expect_setequal(sleep$value, c("AsleepCore", "Awake"))
  expect_true(all(is.na(sleep$value_num)))
  # timestamps parsed to POSIXct, ordered
  expect_s3_class(ah$records$start, "POSIXct")
  expect_false(is.unsorted(ah$records$start))
})

test_that("readAppleHealth parses workouts", {
  ah <- readAppleHealth(make_apple_export())
  expect_equal(nrow(ah$workouts), 1L)
  expect_equal(ah$workouts$activity, "Running")
  expect_equal(ah$workouts$duration, 30.5)
  expect_equal(ah$workouts$energy_kcal, 320)
})

test_that("appleHealthTypes / appleHealthSeries / appleHealthExperiment work", {
  ah <- readAppleHealth(make_apple_export())
  ty <- appleHealthTypes(ah)
  expect_equal(ty$n[ty$type == "HeartRate"], 2L)

  hr <- appleHealthSeries(ah, "HeartRate")
  expect_equal(hr$value_num, c(62, 68))
  expect_error(appleHealthSeries(ah, "NotAType"), "No records of type")

  pe <- appleHealthExperiment(ah, "HeartRate")
  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(SummarizedExperiment::assay(pe, "raw")[, 1], c(62, 68))
  expect_true(is.na(samplingRate(pe)))                          # irregular
  expect_length(S4Vectors::metadata(pe)$times, 2L)
  # a category modality cannot become a numeric experiment
  expect_error(appleHealthExperiment(ah, "SleepAnalysis"), "not numeric")
})

test_that("types filter and bad-file handling", {
  ah <- readAppleHealth(make_apple_export(), types = "HeartRate")
  expect_setequal(unique(ah$records$type), "HeartRate")
  expect_error(readAppleHealth(tempfile()), "not found")
  bogus <- tempfile(fileext = ".xml"); writeLines("<not><an>export</an></not>", bogus)
  expect_error(readAppleHealth(bogus), "No <Record>")
})

test_that("readAppleECG parses the single-lead trace and header", {
  f <- tempfile(fileext = ".csv")
  writeLines(c(
    "Name,Test User",
    "Date of Birth,1990-01-01",
    "Recorded Date,2023-05-01 07:14:22 -0800",
    "Classification,Sinus Rhythm",
    "Sample Rate,512 Hz",
    "Lead,Lead I",
    "Unit,µV",
    paste0(round(sin(seq_len(2560) / 20) * 200, 1))   # 5 s @ 512 Hz
  ), f)
  ecg <- readAppleECG(f)
  expect_s4_class(ecg, "PhysioExperiment")
  expect_equal(samplingRate(ecg), 512)
  expect_equal(nrow(SummarizedExperiment::assay(ecg, "raw")), 2560L)
  expect_equal(S4Vectors::metadata(ecg)$classification, "Sinus Rhythm")
})
