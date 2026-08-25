library(PhysioDevices)
library(testthat)

gt3x_sample <- function()
  system.file("extdata", "TAS1H30182785_2019-09-17.gt3x", package = "read.gt3x")

cwa_sample <- function() {
  f <- list.files(system.file(package = "GGIRread"), recursive = TRUE,
                  pattern = "\\.cwa$", full.names = TRUE)
  if (length(f)) f[1] else ""
}

test_that("readGT3X reads the bundled ActiGraph sample into an accel experiment", {
  skip_if_not_installed("read.gt3x")
  f <- gt3x_sample(); skip_if(!nzchar(f), "read.gt3x sample not available")
  pe <- readGT3X(f)
  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(samplingRate(pe), 100)
  a <- SummarizedExperiment::assay(pe, "acceleration")
  expect_equal(ncol(a), 3L)
  expect_setequal(colnames(a), c("x", "y", "z"))
  expect_gt(nrow(a), 1000)
  expect_equal(S4Vectors::metadata(pe)$source_device, "ActiGraph")
})

test_that("readCWA reads the bundled Axivity sample into an accel experiment", {
  skip_if_not_installed("GGIRread")
  f <- cwa_sample(); skip_if(!nzchar(f), "GGIRread sample not available")
  pe <- suppressWarnings(readCWA(f))
  expect_s4_class(pe, "PhysioExperiment")
  expect_equal(samplingRate(pe), 100)
  a <- SummarizedExperiment::assay(pe, "acceleration")
  expect_equal(ncol(a), 3L)
  expect_setequal(colnames(a), c("x", "y", "z"))
  expect_gt(nrow(a), 100)
  expect_equal(S4Vectors::metadata(pe)$source_device, "Axivity")
})

test_that("readGT3X output feeds the free-living ENMO pipeline", {
  skip_if_not_installed("read.gt3x")
  skip_if_not_installed("PhysioWearable")
  f <- gt3x_sample(); skip_if(!nzchar(f), "sample not available")
  pe <- readGT3X(f)
  a <- SummarizedExperiment::assay(pe, "acceleration")
  enmo <- PhysioWearable::computeENMO(a, sampling_rate = samplingRate(pe))
  expect_gt(length(unlist(enmo)), 0)          # produces ENMO values
})

test_that("readGENEActiv reads the bundled sample into an accel experiment", {
  skip_if_not_installed("GGIRread")
  f <- list.files(system.file(package = "GGIRread"), recursive = TRUE,
                  pattern = "\\.bin$", full.names = TRUE)
  skip_if(!length(f), "GGIRread GENEActiv sample not available")
  # GGIRread's bundled fixture is degenerate (NA times, header rate -1), so the
  # rate is supplied here; real files carry it in the header.
  # GGIRread's bundled fixture is a tiny structural sample (degenerate header/
  # timestamps), so this checks the adapter wraps GGIRread into the right shape;
  # decode correctness is GGIRread's own responsibility.
  pe <- suppressWarnings(readGENEActiv(f[1], end = 5, sampling_rate = 100))
  expect_s4_class(pe, "PhysioExperiment")
  a <- SummarizedExperiment::assay(pe, "acceleration")
  expect_equal(ncol(a), 3L)
  expect_setequal(colnames(a), c("x", "y", "z"))
  expect_equal(S4Vectors::metadata(pe)$source_device, "GENEActiv")
  expect_equal(samplingRate(pe), 100)
})

test_that("error handling for missing files", {
  expect_error(readGT3X(tempfile(fileext = ".gt3x")), "not found")
  expect_error(readCWA(tempfile(fileext = ".cwa")), "not found")
  expect_error(readGENEActiv(tempfile(fileext = ".bin")), "not found")
})
