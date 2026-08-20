library(testthat)
library(PhysioDevices)

test_that("readShimmer reproduces calibrated GSR values, units and rate", {
  f <- system.file("extdata", "shimmer_gsr3.csv", package = "PhysioDevices")
  skip_if(f == "", "Shimmer fixture not found")
  pe <- readShimmer(f)
  expect_s4_class(pe, "PhysioExperiment")

  data <- SummarizedExperiment::assay(pe, "raw")
  expect_true("GSR_Skin_Conductance" %in% colnames(data))
  expect_equal(data[, "GSR_Skin_Conductance"],
               c(5.12, 5.15, 5.18, 5.20, 5.22))
  # timestamps 20 ms apart -> 50 Hz
  expect_equal(samplingRate(pe), 50)

  cd <- SummarizedExperiment::colData(pe)
  gsr_unit <- as.character(cd$unit)[cd$label == "GSR_Skin_Conductance"]
  expect_equal(gsr_unit, "uS")
  expect_false("Timestamp_Unix" %in% colnames(data))  # timestamp column dropped
})

test_that("readShimmer preserves the accelerometer channels", {
  f <- system.file("extdata", "shimmer_gsr3.csv", package = "PhysioDevices")
  skip_if(f == "", "Shimmer fixture not found")
  pe <- readShimmer(f)
  labs <- channelNames(pe)
  expect_true(all(c("Accel_LN_X", "Accel_LN_Y", "Accel_LN_Z") %in% labs))
  z <- SummarizedExperiment::assay(pe, "raw")[, "Accel_LN_Z"]
  expect_equal(z, c(9.79, 9.80, 9.78, 9.81, 9.79))
})

test_that("readShimmer records a provenance import step", {
  f <- system.file("extdata", "shimmer_gsr3.csv", package = "PhysioDevices")
  skip_if(f == "", "Shimmer fixture not found")
  pe <- readShimmer(f)
  expect_true("readShimmer" %in% PhysioCore::provenance(pe)$activity)
})

# ---- regression tests for adversarial-review findings (DMIO-16) -------------

test_that("a short units row only NA-fills the missing channels", {
  tf <- tempfile(fileext = ".csv")
  writeLines(c(
    paste("Shimmer_A_Timestamp_Unix_CAL", "Shimmer_A_GSR_Skin_Conductance_CAL",
          "Shimmer_A_PPG_A13_CAL", sep = "\t"),
    paste("ms", "uS", sep = "\t"),                       # PPG unit missing
    paste(1700000000000, 5.1, 1500, sep = "\t"),
    paste(1700000000020, 5.2, 1502, sep = "\t")), tf)
  pe <- readShimmer(tf)
  cd <- SummarizedExperiment::colData(pe)
  expect_equal(as.character(cd$unit)[cd$label == "GSR_Skin_Conductance"], "uS")
  expect_true(is.na(as.character(cd$unit)[cd$label == "PPG_A13"]))
})

test_that("readShimmer rejects a ragged data row", {
  tf <- tempfile(fileext = ".csv")
  writeLines(c(
    paste("Shimmer_A_Timestamp_Unix_CAL", "Shimmer_A_GSR_Skin_Conductance_CAL",
          sep = "\t"),
    paste("ms", "uS", sep = "\t"),
    paste(1700000000000, 5.1, sep = "\t"),
    "1700000000020"), tf)
  expect_error(readShimmer(tf), "inconsistent column count")
})
