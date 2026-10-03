library(testthat)
library(PhysioDevices)

mvnx_file <- function() {
  system.file("extdata", "xsens_sample.mvnx", package = "PhysioDevices")
}

test_that("readXsensMVNX yields segment/joint/CoM streams at the frame rate", {
  f <- mvnx_file()
  skip_if(f == "", "MVNX fixture not found")
  skip_if_not_installed("xml2")
  mr <- readXsensMVNX(f)
  expect_s4_class(mr, "MultiRatePhysioExperiment")
  expect_setequal(
    PhysioCore::streamNames(mr),
    c("position", "orientation", "acceleration", "jointAngle", "centerOfMass"))
  # all signals share the subject frame rate (240 Hz)
  expect_true(all(PhysioCore::streamRates(mr) == 240))
})

test_that("readXsensMVNX reproduces segment position frames from the XML", {
  f <- mvnx_file()
  skip_if(f == "", "MVNX fixture not found")
  skip_if_not_installed("xml2")
  mr <- readXsensMVNX(f)
  pos <- SummarizedExperiment::assay(PhysioCore::streams(mr)[["position"]], "raw")
  # only the two "normal" frames (the identity frame is skipped)
  expect_equal(dim(pos), c(2L, 6L))
  expect_equal(colnames(pos),
               c("Pelvis_x", "Pelvis_y", "Pelvis_z", "L5_x", "L5_y", "L5_z"))
  expect_equal(unname(pos[1, ]), c(0.10, 0.20, 0.90, 0.11, 0.21, 1.10))
  expect_equal(unname(pos[2, ]), c(0.101, 0.201, 0.901, 0.111, 0.211, 1.101))
})

test_that("readXsensMVNX orientation and joint-angle counts match the schema", {
  f <- mvnx_file()
  skip_if(f == "", "MVNX fixture not found")
  skip_if_not_installed("xml2")
  mr <- readXsensMVNX(f)
  ori <- SummarizedExperiment::assay(
    PhysioCore::streams(mr)[["orientation"]], "raw")
  expect_equal(ncol(ori), 8L)   # 4 quaternion components x 2 segments
  ja <- SummarizedExperiment::assay(
    PhysioCore::streams(mr)[["jointAngle"]], "raw")
  expect_equal(ncol(ja), 3L)    # 3 angles x 1 joint
  expect_equal(colnames(ja), c("jL5S1_x", "jL5S1_y", "jL5S1_z"))
})

test_that("readXsensMVNX records a provenance step", {
  f <- mvnx_file()
  skip_if(f == "", "MVNX fixture not found")
  skip_if_not_installed("xml2")
  mr <- readXsensMVNX(f)
  prov <- PhysioCore::provenance(PhysioCore::streams(mr)[["position"]])
  expect_true("readXsensMVNX" %in% prov$activity)
})

# ---- regression tests for adversarial-review findings (DMIO-17) -------------

test_that("an oversized corrupt frame does not NA-wipe well-formed frames", {
  skip_if_not_installed("xml2")
  mvnx <- paste0(
    '<?xml version="1.0"?>',
    '<mvnx xmlns="http://www.xsens.com/mvn/mvnx"><subject frameRate="100" ',
    'segmentCount="1"><segments><segment id="1" label="Pelvis"/></segments>',
    '<joints></joints><frames segmentCount="1">',
    '<frame time="0" index="0" type="normal"><position>1 2 3</position></frame>',
    '<frame time="0.01" index="1" type="normal"><position>4 5 6</position></frame>',
    '<frame time="0.02" index="2" type="normal"><position>7 8 9 99</position></frame>',
    '</frames></subject></mvnx>')
  tf <- tempfile(fileext = ".mvnx")
  writeLines(mvnx, tf)
  expect_warning(mr <- readXsensMVNX(tf), "unexpected value count")
  pos <- SummarizedExperiment::assay(PhysioCore::streams(mr)[["position"]], "raw")
  expect_equal(ncol(pos), 3L)                 # canonical count from frame 1
  expect_equal(unname(pos[1, ]), c(1, 2, 3))  # good frames preserved
  expect_equal(unname(pos[2, ]), c(4, 5, 6))
  expect_true(all(is.na(pos[3, ])))           # the oversized frame is NA
})
