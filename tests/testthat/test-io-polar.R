library(testthat)
library(PhysioDevices)

test_that("readPolar reproduces heart rate and R-R interval events", {
  f <- system.file("extdata", "polar_hr.csv", package = "PhysioDevices")
  skip_if(f == "", "Polar fixture not found")
  pe <- readPolar(f)
  expect_s4_class(pe, "PhysioExperiment")

  hr <- SummarizedExperiment::assay(pe, "raw")[, 1]
  expect_equal(hr, c(72, 73, 72, 74, 75))
  expect_equal(samplingRate(pe), 1)   # Time column 1 s apart

  ev <- PhysioCore::getEvents(pe)@events
  expect_equal(nrow(ev), 5L)
  expect_true(all(ev$type == "RR"))
  expect_equal(ev$value, as.character(c(833, 822, 840, 810, 800)))
  # first R-R interval starts at onset 0, the second at 0.833 s
  expect_equal(ev$onset[1], 0)
  expect_equal(ev$onset[2], 0.833, tolerance = 1e-9)
})

test_that("readPolar derives instantaneous HR when only R-R is present", {
  tf <- tempfile(fileext = ".csv")
  writeLines(c("RR", "800", "820", "810"), tf)
  pe <- readPolar(tf)
  hr <- SummarizedExperiment::assay(pe, "raw")[, 1]
  expect_equal(hr, 60000 / c(800, 820, 810))
  expect_equal(PhysioCore::nEvents(PhysioCore::getEvents(pe)), 3L)
})

test_that("readPolar errors when neither HR nor R-R is present", {
  tf <- tempfile(fileext = ".csv")
  writeLines(c("Time,Speed", "0,1.2", "1,1.3"), tf)
  expect_error(readPolar(tf), "no heart-rate or R-R")
})

# ---- regression tests for adversarial-review findings (DMIO-16) -------------

test_that("readPolar column matching avoids substring false positives", {
  tf <- tempfile(fileext = ".csv")
  # "Threshold" contains 'hr'; "Corrected" contains 'rr' -- neither must match.
  writeLines(c("Threshold,Corrected,HR", "1,2,72", "3,4,73"), tf)
  pe <- readPolar(tf)
  expect_equal(SummarizedExperiment::assay(pe, "raw")[, 1], c(72, 73))
})

test_that("readPolar parses a HH:MM:SS time column for the sampling rate", {
  tf <- tempfile(fileext = ".csv")
  writeLines(c("Time,HR", "00:00:00,72", "00:00:01,73", "00:00:02,74"), tf)
  pe <- readPolar(tf)
  expect_equal(samplingRate(pe), 1)
})

test_that("readPolar rejects a ragged data row", {
  tf <- tempfile(fileext = ".csv")
  writeLines(c("Time,HR,RR", "0,72,833", "1,73"), tf)
  expect_error(readPolar(tf), "inconsistent column count")
})
