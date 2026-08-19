# Read an Oura Ring export

Parses an Oura sleep export/JSON (API v2 `sleep` collection) into tidy
per-night data: sleep-stage intervals (from the 5-minute hypnogram), the
5-minute heart-rate and HRV (RMSSD) series, and Oura's own sleep
summary.

## Usage

``` r
readOura(path, tz = "UTC")
```

## Arguments

- path:

  Path to the Oura sleep JSON (an object with a `data` array, or a bare
  array of sleep periods).

- tz:

  Time zone for the parsed timestamps (default `"UTC"`).

## Value

An `oura` object: a list with `sleep` (stage intervals `start`, `end`,
`stage`, `day`), `sleep_summary` (per-day `efficiency`,
`total_sleep_min`, `time_in_bed_min`), `heart_rate` (`time`, `bpm`) and
`hrv` (`time`, `rmssd`), plus `path`/`tz`. The `sleep` stages feed
`PhysioWearable::summarizeSleepStages()`.

## References

Oura API v2 sleep data.

## See also

[`readFitbit()`](https://x-biosignal.github.io/PhysioDevices/reference/readFitbit.md),
[`readHealthConnect()`](https://x-biosignal.github.io/PhysioDevices/reference/readHealthConnect.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ou <- readOura("oura_sleep.json", tz = "Asia/Tokyo")
PhysioWearable::summarizeSleepStages(ou$sleep,
  asleep_levels = c("light", "deep", "rem"))
} # }
```
