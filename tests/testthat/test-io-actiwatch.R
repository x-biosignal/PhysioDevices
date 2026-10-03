library(PhysioDevices)
library(testthat)

make_awd <- function() {
  f <- tempfile(fileext = ".awd")
  writeLines(c("SUBJECT01", "01-May-2023", "23:00", "1", "30", "M", "V700",
               "0", "5", "12", "40", "8", "2"), f)
  f
}

test_that("readActiwatch parses the header time and activity counts", {
  aw <- readActiwatch(make_awd(), epoch = 60, tz = "UTC")
  expect_s3_class(aw, "data.frame")
  expect_equal(aw$activity, c(0, 5, 12, 40, 8, 2))       # the longest numeric run
  expect_equal(as.numeric(aw$time[1]),
               as.numeric(as.POSIXct("2023-05-01 23:00:00", tz = "UTC")))
  expect_equal(as.numeric(difftime(aw$time[2], aw$time[1], units = "secs")), 60)
  expect_equal(attr(aw, "epoch_sec"), 60)
})

test_that("readActiwatch counts feed the actigraphy sleep scorer", {
  skip_if_not_installed("PhysioWearable")
  aw <- readActiwatch(make_awd(), epoch = 60)
  sw <- PhysioWearable::coleKripke(aw$activity, rescore = FALSE)
  expect_length(sw, nrow(aw))
  expect_true(all(sw %in% c(0L, 1L)))
})

test_that("error / no-data handling", {
  expect_error(readActiwatch(tempfile(fileext = ".awd")), "not found")
  expect_error(readActiwatch(make_awd(), epoch = -1), "positive")
  f <- tempfile(fileext = ".awd"); writeLines(c("name", "no", "numbers", "here"), f)
  expect_error(suppressWarnings(readActiwatch(f)), "No activity-count data")
})
