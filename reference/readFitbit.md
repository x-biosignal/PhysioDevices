# Read a Fitbit / Google Pixel data archive

Parses a Fitbit account-export (or Google Takeout) directory into tidy
per-modality series. Files are discovered by name: `heart_rate-*` (bpm),
`steps-*`, `resting_heart_rate-*`, SpO2 (`spo2*`/`*oxygen*`, JSON or
minute CSV), and `sleep-*` (Fitbit's own `wake`/`light`/`deep`/`rem`
stages). Google Pixel Watch health data is stored in Fitbit, so the same
reader covers it.

## Usage

``` r
readFitbit(path, what = NULL, tz = "UTC")
```

## Arguments

- path:

  Directory of the extracted archive (searched recursively), or a file /
  vector of files.

- what:

  Optional character vector restricting which modalities to read (any of
  `"heart_rate"`, `"steps"`, `"spo2"`, `"resting_heart_rate"`,
  `"sleep"`); `NULL` (default) reads all that are found.

- tz:

  Time zone for the parsed timestamps (default `"UTC"`).

## Value

A `fitbit` object: a list with any of `heart_rate`, `steps`, `spo2`,
`resting_heart_rate` (data frames of `time`, `value`), `sleep` (stage
intervals `start`, `end`, `stage`, `log_id`) and `sleep_summary`
(Fitbit's per-log `efficiency`, `minutes_asleep`, `time_in_bed`, ...),
plus `path`/`tz`. The `sleep` stages feed
`PhysioWearable::summarizeSleepStages()`; `spo2` feeds
`PhysioWearable::spo2Metrics()`.

## References

Fitbit Web API data types; Fitbit account data export.

## See also

[`readAppleHealth()`](https://x-biosignal.github.io/PhysioDevices/reference/readAppleHealth.md),
[`fitbitSeries()`](https://x-biosignal.github.io/PhysioDevices/reference/fitbitSeries.md)

## Examples

``` r
if (FALSE) { # \dontrun{
fb <- readFitbit("Takeout/Fitbit", tz = "Asia/Tokyo")
fb
PhysioWearable::spo2Metrics(fb$spo2$value, time = fb$spo2$time)
} # }
```
