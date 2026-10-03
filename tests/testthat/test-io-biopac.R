library(testthat)
library(PhysioDevices)

acq_file <- function() {
  system.file("extdata", "biopac_sample.acq", package = "PhysioDevices")
}

test_that("hasBioread reports availability as a logical", {
  expect_type(hasBioread(), "logical")
})

test_that("readBIOPAC reproduces per-channel rates and channel data", {
  f <- acq_file()
  skip_if(f == "", "BIOPAC fixture not found")
  skip_if_not(hasBioread(), "Python 'bioread' not available")
  mr <- readBIOPAC(f)
  expect_s4_class(mr, "MultiRatePhysioExperiment")
  expect_setequal(PhysioCore::streamNames(mr), c("ECG", "Resp"))

  rates <- PhysioCore::streamRates(mr)
  expect_equal(unname(rates["ECG"]), 1000)   # frequency divider 1
  expect_equal(unname(rates["Resp"]), 500)   # frequency divider 2

  ecg <- PhysioCore::streams(mr)[["ECG"]]
  resp <- PhysioCore::streams(mr)[["Resp"]]
  expect_equal(SummarizedExperiment::assay(ecg, "raw")[, 1], c(1, 2, 3, 4))
  expect_equal(SummarizedExperiment::assay(resp, "raw")[, 1], c(10, 20))
  expect_equal(as.character(SummarizedExperiment::colData(ecg)$unit), "mV")
})

test_that("readBIOPAC maps markers to events at the correct position", {
  f <- acq_file()
  skip_if(f == "", "BIOPAC fixture not found")
  skip_if_not(hasBioread(), "Python 'bioread' not available")
  mr <- readBIOPAC(f)
  ecg <- PhysioCore::streams(mr)[["ECG"]]  # fastest stream hosts the markers
  ev <- PhysioCore::getEvents(ecg)@events
  expect_equal(nrow(ev), 1L)
  expect_equal(ev$onset, 2 / 1000)   # sample index 2 at the 1000 Hz base rate
  expect_equal(ev$value, "stim")
})

test_that("readBIOPAC records a provenance step", {
  f <- acq_file()
  skip_if(f == "", "BIOPAC fixture not found")
  skip_if_not(hasBioread(), "Python 'bioread' not available")
  mr <- readBIOPAC(f)
  prov <- PhysioCore::provenance(PhysioCore::streams(mr)[["ECG"]])
  expect_true("readBIOPAC" %in% prov$activity)
})

test_that("readBIOPAC errors clearly without a bioread backend", {
  expect_true(is.function(readBIOPAC))
  expect_error(readBIOPAC("/no/such/file.acq"), "not found")
})
