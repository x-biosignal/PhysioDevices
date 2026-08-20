library(testthat)
library(PhysioDevices)

delsys_file <- function() {
  system.file("extdata", "delsys_trigno.csv", package = "PhysioDevices")
}

test_that("readDelsysTrigno separates EMG and IMU streams at their own rates", {
  f <- delsys_file()
  skip_if(f == "", "Delsys fixture not found")
  mr <- readDelsysTrigno(f)
  expect_s4_class(mr, "MultiRatePhysioExperiment")
  expect_setequal(PhysioCore::streamNames(mr), c("emg", "imu"))
  r <- PhysioCore::streamRates(mr)
  expect_equal(unname(r["emg"]), 1000)   # EMG X[s] steps 0.001
  expect_equal(unname(r["imu"]), 250)    # ACC X[s] steps 0.004
})

test_that("readDelsysTrigno reproduces channel values and per-sensor colData", {
  f <- delsys_file()
  skip_if(f == "", "Delsys fixture not found")
  mr <- readDelsysTrigno(f)
  emg <- PhysioCore::streams(mr)[["emg"]]
  imu <- PhysioCore::streams(mr)[["imu"]]

  expect_equal(SummarizedExperiment::assay(emg, "raw")[, "EMG1"],
               c(0.001, 0.002, 0.003, 0.004))
  imu_data <- SummarizedExperiment::assay(imu, "raw")
  expect_equal(dim(imu_data), c(2L, 3L))
  expect_equal(imu_data[, "ACC.X"], c(0.10, 0.11))

  # per-sensor column metadata
  cd_emg <- SummarizedExperiment::colData(emg)
  expect_equal(cd_emg$sensor, 1L)
  expect_equal(cd_emg$type, "EMG")
  cd_imu <- SummarizedExperiment::colData(imu)
  expect_true(all(cd_imu$type == "ACC"))
  expect_true(all(cd_imu$sensor == 1L))
})

test_that("readDelsysTrigno records a provenance step and errors on empty input", {
  f <- delsys_file()
  skip_if(f == "", "Delsys fixture not found")
  mr <- readDelsysTrigno(f)
  prov <- PhysioCore::provenance(PhysioCore::streams(mr)[["emg"]])
  expect_true("readDelsysTrigno" %in% prov$activity)

  tf <- tempfile(fileext = ".csv")
  writeLines(c("Time,Speed", "0,1.2"), tf)
  expect_error(readDelsysTrigno(tf), "no Trigno data header")
})

# ---- regression tests for adversarial-review findings (DMIO-17) -------------

test_that("readDelsysTrigno handles a single shared time column", {
  tf <- tempfile(fileext = ".csv")
  writeLines(c(
    "X[s],Sensor 1: EMG1 (V),Sensor 2: EMG2 (V)",
    "0,0.1,0.2", "0.001,0.11,0.21", "0.002,0.12,0.22"), tf)
  mr <- readDelsysTrigno(tf)
  emg <- PhysioCore::streams(mr)[["emg"]]
  # both EMG channels captured (not just the one after X[s])
  expect_equal(ncol(SummarizedExperiment::assay(emg, "raw")), 2L)
  expect_equal(SummarizedExperiment::assay(emg, "raw")[, "EMG1"],
               c(0.1, 0.11, 0.12))
  expect_equal(SummarizedExperiment::assay(emg, "raw")[, "EMG2"],
               c(0.2, 0.21, 0.22))
})

test_that("readDelsysTrigno splits IMU channels of differing rates into streams", {
  tf <- tempfile(fileext = ".csv")
  writeLines(c(
    "X[s],Sensor 1: ACC.X (g),X[s],Sensor 1: GYRO.X (deg/s)",
    "0,0.1,0,5",
    "0.004,0.11,0.008,6",
    "0.008,0.12,,",
    "0.012,0.13,,"), tf)
  mr <- readDelsysTrigno(tf)   # ACC at 250 Hz (4 samples), GYRO at 125 Hz (2)
  nm <- PhysioCore::streamNames(mr)
  expect_true(length(grep("^imu", nm)) == 2)
})

test_that("readDelsysTrigno errors on a header-only export and on long rows", {
  tf1 <- tempfile(fileext = ".csv")
  writeLines("X[s],Sensor 1: EMG1 (V)", tf1)
  expect_error(readDelsysTrigno(tf1), "no data rows")

  tf2 <- tempfile(fileext = ".csv")
  writeLines(c("X[s],Sensor 1: EMG1 (V)", "0,0.1", "0.001,0.2,EXTRA"), tf2)
  expect_error(readDelsysTrigno(tf2), "more fields than the header")
})
