library(testthat)
library(PhysioDevices)

# ---- FIT (Garmin/ANT+) via FITfileR delegation -----------------------------
# No .fit sample is bundled (FITfileR is GitHub/r-universe-only), so the adapter
# is tested on a synthetic FITfileR-style record data frame.

test_that(".fit_track adapts a record data frame to trackpoints", {
  rec <- data.frame(
    timestamp     = as.POSIXct(c("2024-01-01 00:00:01", "2024-01-01 00:00:00"), tz = "UTC"),
    position_lat  = c(35.0001, 35.0000),
    position_long = c(139.0001, 139.0000),
    altitude      = c(11, 10),
    distance      = c(5, 0),
    heart_rate    = c(122, 120),
    cadence       = c(82, 80),
    speed         = c(3.1, 3.0),
    power         = c(210, 200),
    stringsAsFactors = FALSE)

  tp <- PhysioDevices:::.fit_track(rec, "UTC")

  expect_s3_class(tp$time, "POSIXct")
  expect_equal(nrow(tp), 2L)
  expect_true(!is.unsorted(tp$time))          # sorted ascending
  expect_equal(tp$hr, c(120, 122))            # follows the time sort
  expect_equal(tp$power, c(200, 210))
  expect_named(tp, c("time", "lat", "lon", "altitude_m", "distance_m",
                     "hr", "cadence", "speed", "power"))
})

test_that(".fit_track fills absent optional columns with NA", {
  rec <- data.frame(timestamp = as.POSIXct("2024-01-01", tz = "UTC"),
                    heart_rate = 130, stringsAsFactors = FALSE)
  tp <- PhysioDevices:::.fit_track(rec, "UTC")
  expect_equal(tp$hr, 130)
  expect_true(is.na(tp$power))
  expect_true(is.na(tp$lat))
})

test_that(".fit_bind unions columns across multiple record frames", {
  a <- data.frame(timestamp = 1:2, heart_rate = c(100, 101))
  b <- data.frame(timestamp = 3:4, power = c(200, 201))
  bound <- PhysioDevices:::.fit_bind(list(a, b))
  expect_equal(nrow(bound), 4L)
  expect_true(all(c("timestamp", "heart_rate", "power") %in% names(bound)))
  expect_true(is.na(bound$power[1]))          # row from `a` has no power
  expect_true(is.na(bound$heart_rate[3]))     # row from `b` has no heart_rate
})

test_that("readFIT validates its path before delegating", {
  expect_error(readFIT("no_such_file.fit"), "not found")
})

# Real Garmin/ANT+ .fit files ship with FITfileR -> validate readFIT end to end.
test_that("readFIT reads a real Garmin ride and masks FIT invalid sentinels", {
  skip_if_not_installed("FITfileR")
  f <- system.file("extdata", "Activities", "garmin-edge530-ride.fit", package = "FITfileR")
  skip_if(!nzchar(f), "FITfileR sample not available")
  tp <- readFIT(f)
  expect_s3_class(tp$time, "POSIXct")
  expect_gt(nrow(tp), 1000)
  expect_true(!is.unsorted(tp$time))
  expect_true(any(!is.na(tp$lat)))                      # genuine GPS track
  expect_false(any(tp$hr == 255, na.rm = TRUE))         # 0xFF sentinel -> NA
  expect_false(any(tp$power == 65535, na.rm = TRUE))    # 0xFFFF sentinel -> NA
  expect_true(all(is.na(tp$hr)))                        # this ride had no HR strap
})

test_that("readFIT recovers plausible heart rate from a real Garmin swim", {
  skip_if_not_installed("FITfileR")
  f <- system.file("extdata", "Activities", "garmin-fenix6-swim.fit", package = "FITfileR")
  skip_if(!nzchar(f), "FITfileR sample not available")
  tp <- readFIT(f)
  hr <- tp$hr[!is.na(tp$hr)]
  expect_gt(length(hr), 10)
  expect_true(all(hr > 30 & hr < 220))                  # physiologically plausible
})

# ---- Whoop -----------------------------------------------------------------

test_that("readWhoop parses sleep and recovery summaries", {
  dir <- file.path(tempfile("whoop"))
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  writeLines(c(
    '"Cycle start time","Sleep efficiency %","Light sleep duration (min)","Deep (SWS) duration (min)","REM duration (min)","Awake duration (min)","Respiratory rate (rpm)","Heart rate variability (ms)"',
    '"2024-01-01","88","210","95","70","20","14.5","65"',
    '"2024-01-02","90","200","100","72","18","14.2","70"'),
    file.path(dir, "sleeps.csv"))
  writeLines(c(
    '"Cycle start time","Recovery score %","Resting heart rate (bpm)","Heart rate variability (ms)","Blood oxygen %","Skin temp (celsius)"',
    '"2024-01-01","66","52","65","97","33.1"',
    '"2024-01-02","74","50","70","98","33.0"'),
    file.path(dir, "physiological_cycles.csv"))

  w <- readWhoop(dir)
  expect_s3_class(w, "whoop")
  expect_equal(w$sleep$deep_min, c(95, 100))
  expect_equal(w$sleep$rem_min, c(70, 72))
  expect_equal(w$sleep$hrv_ms, c(65, 70))
  expect_equal(w$recovery$recovery, c(66, 74))
  expect_equal(w$recovery$resting_hr, c(52, 50))
  expect_equal(w$recovery$spo2, c(97, 98))
})

test_that("readWhoop errors on a directory with no recognised CSVs", {
  dir <- file.path(tempfile("whoopx"))
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  writeLines("a,b\n1,2", file.path(dir, "unrelated.csv"))
  expect_error(readWhoop(dir), "No recognised Whoop")
})

# ---- Withings --------------------------------------------------------------

test_that("readWithings parses heart rate, SpO2, blood pressure and weight", {
  dir <- file.path(tempfile("withings"))
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  writeLines(c("start,duration,value",
               "2024-01-01 07:00:00,60,61",
               "2024-01-01 07:01:00,60,63"), file.path(dir, "raw_hr_hr.csv"))
  writeLines(c("start,value",
               "2024-01-01 07:00:00,97",
               "2024-01-01 07:05:00,98"), file.path(dir, "spo2.csv"))
  writeLines(c("Date,Heart Rate,Systolic (mmHg),Diastolic (mmHg)",
               "2024-01-01 08:00:00,60,120,78"), file.path(dir, "bp.csv"))
  writeLines(c("Date,Weight (kg)",
               "2024-01-01 06:00:00,70.5"), file.path(dir, "weight.csv"))

  w <- readWithings(dir, tz = "UTC")
  expect_s3_class(w, "withings")
  expect_equal(w$heart_rate$bpm, c(61, 63))
  expect_equal(w$spo2$value, c(97, 98))
  expect_equal(w$blood_pressure$systolic, 120)
  expect_equal(w$blood_pressure$diastolic, 78)
  expect_equal(w$weight$kg, 70.5)
  expect_s3_class(w$spo2$time, "POSIXct")
})

# ---- Samsung Health --------------------------------------------------------

test_that("readSamsungHealth parses HR/SpO2/steps past the metadata header line", {
  dir <- file.path(tempfile("samsung"))
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  writeLines(c("com.samsung.shealth.tracker.heart_rate,4,...",
               "start_time,heart_rate",
               "2024-01-01 07:00:00,72",
               "2024-01-01 07:01:00,75"),
             file.path(dir, "com.samsung.shealth.tracker.heart_rate.202401.csv"))
  writeLines(c("com.samsung.health.oxygen_saturation,2,...",
               "start_time,spo2",
               "2024-01-01 07:00:00,97"),
             file.path(dir, "com.samsung.health.oxygen_saturation.202401.csv"))
  # steps file uses epoch-millisecond timestamps -> exercises the ms branch
  writeLines(c("com.samsung.shealth.step_count,6,...",
               "day_time,count",
               "1704092400000,1200"),
             file.path(dir, "com.samsung.shealth.step_count.202401.csv"))

  sh <- readSamsungHealth(dir, tz = "UTC")
  expect_s3_class(sh, "samsung_health")
  expect_equal(sh$heart_rate$bpm, c(72, 75))
  expect_s3_class(sh$heart_rate$time, "POSIXct")
  expect_equal(sh$spo2$value, 97)
  expect_equal(sh$steps$value, 1200)
  expect_equal(as.integer(format(sh$steps$time, "%Y", tz = "UTC")), 2024L)  # ms parsed
})

test_that(".samsung_time handles both ISO strings and epoch millis", {
  t <- PhysioDevices:::.samsung_time(c("2024-01-01 07:00:00", "1704092400000"), "UTC")
  expect_s3_class(t, "POSIXct")
  expect_equal(format(t[2], "%Y-%m-%d", tz = "UTC"), "2024-01-01")
})
