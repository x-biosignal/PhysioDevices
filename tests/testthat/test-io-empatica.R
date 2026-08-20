library(testthat)
library(PhysioDevices)

e4_dir <- function() {
  system.file("extdata", "e4_sample", package = "PhysioDevices")
}

test_that("readEmpaticaE4 yields distinct per-signal streams at correct rates", {
  d <- e4_dir()
  skip_if(d == "", "E4 sample fixture not found")
  mr <- readEmpaticaE4(d)
  expect_s4_class(mr, "MultiRatePhysioExperiment")

  rates <- PhysioCore::streamRates(mr)
  expect_equal(unname(rates["eda"]), 4)
  expect_equal(unname(rates["bvp"]), 64)
  expect_equal(unname(rates["acc"]), 32)
  expect_equal(unname(rates["temp"]), 4)
  expect_equal(unname(rates["hr"]), 1)
  expect_setequal(PhysioCore::streamNames(mr),
                  c("eda", "bvp", "acc", "temp", "hr"))
})

test_that("readEmpaticaE4 aligns streams by their StartTime offsets", {
  d <- e4_dir()
  skip_if(d == "", "E4 sample fixture not found")
  mr <- readEmpaticaE4(d)
  off <- PhysioCore::commonClock(mr)$offsets
  # EDA/BVP/ACC/TEMP share the session start; HR starts 10 s later.
  expect_equal(unname(off["eda"]), 0)
  expect_equal(unname(off["bvp"]), 0)
  expect_equal(unname(off["acc"]), 0)
  expect_equal(unname(off["hr"]), 10)
})

test_that("readEmpaticaE4 reproduces signal values and channel layout", {
  d <- e4_dir()
  skip_if(d == "", "E4 sample fixture not found")
  mr <- readEmpaticaE4(d)
  eda <- SummarizedExperiment::assay(PhysioCore::streams(mr)[["eda"]], "raw")
  expect_equal(eda[, 1], c(0.5123, 0.5141, 0.5160, 0.5182, 0.5201, 0.5198,
                           0.5215, 0.5230))
  acc <- SummarizedExperiment::assay(PhysioCore::streams(mr)[["acc"]], "raw")
  expect_equal(ncol(acc), 3L)
  expect_equal(acc[1, ], c(-5, 60, -30))
})

test_that("readEmpaticaE4 attaches IBI and tag events to a stream", {
  d <- e4_dir()
  skip_if(d == "", "E4 sample fixture not found")
  mr <- readEmpaticaE4(d)
  off <- PhysioCore::commonClock(mr)$offsets
  host <- PhysioCore::streams(mr)[[which(off == 0)[1]]]
  ev <- PhysioCore::getEvents(host)@events
  expect_equal(sum(ev$type == "IBI"), 3L)
  expect_equal(sum(ev$type == "tag"), 2L)
  # first tag is at 1700000003 - 1700000000 = 3 s
  expect_equal(ev$onset[ev$type == "tag"][1], 3)
})

test_that("readEmpaticaE4 seeds a provenance import record", {
  d <- e4_dir()
  skip_if(d == "", "E4 sample fixture not found")
  mr <- readEmpaticaE4(d)
  prov <- PhysioCore::provenance(PhysioCore::streams(mr)[["eda"]])
  expect_true("readEmpaticaE4" %in% prov$activity)
})

test_that("readEmpaticaE4 errors on a directory with no signal files", {
  d <- tempfile("empty"); dir.create(d)
  expect_error(readEmpaticaE4(d), "no E4 signal files")
})

test_that("readEmbracePlusAvro decodes an EmbracePlus sample", {
  skip_if_not(hasAvroBackend(), "no Avro backend (fastavro) available")
  f <- system.file("extdata", "embraceplus_sample.avro",
                   package = "PhysioDevices")
  skip_if(f == "", "EmbracePlus avro fixture not found")
  mr <- readEmbracePlusAvro(f)
  expect_s4_class(mr, "MultiRatePhysioExperiment")

  rates <- PhysioCore::streamRates(mr)
  expect_equal(unname(rates["eda"]), 4)
  expect_equal(unname(rates["bvp"]), 64)
  expect_equal(unname(rates["acc"]), 32)
  # temperature starts 2 s after the others
  expect_equal(unname(PhysioCore::commonClock(mr)$offsets["temp"]), 2)

  eda <- SummarizedExperiment::assay(PhysioCore::streams(mr)[["eda"]], "raw")
  expect_equal(eda[, 1], c(0.50, 0.51, 0.52, 0.53), tolerance = 1e-5)
  acc <- SummarizedExperiment::assay(PhysioCore::streams(mr)[["acc"]], "raw")
  expect_equal(dim(acc), c(2L, 3L))
  expect_equal(acc[, 1], c(1, 2))
})

# ---- regression tests for adversarial-review findings (DMIO-16) -------------

test_that("readEmpaticaE4 rejects a ragged (truncated) signal row", {
  d <- tempfile("e4rag"); dir.create(d)
  writeLines(c("1700000000.000000,1700000000.000000,1700000000.000000",
               "32,32,32", "-5,60,-30", "-4,61"), file.path(d, "ACC.csv"))
  expect_error(readEmpaticaE4(d), "inconsistent column count")
})

test_that("a header-only ACC file keeps its 3-channel layout", {
  d <- tempfile("e4empty"); dir.create(d)
  writeLines(c("1700000000.000000,1700000000.000000,1700000000.000000",
               "32,32,32"), file.path(d, "ACC.csv"))
  mr <- readEmpaticaE4(d)
  acc <- SummarizedExperiment::assay(PhysioCore::streams(mr)[["acc"]], "raw")
  expect_equal(ncol(acc), 3L)
  expect_equal(nrow(acc), 0L)
})
