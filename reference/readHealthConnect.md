# Read an Android Health Connect CSV export

Parses a directory of Health Connect record-type CSVs (one file per
type) into tidy per-modality series. Recognises `HeartRate`, `Steps`,
`OxygenSaturation`, `RespiratoryRate` and `SleepSession` (its stages) by
filename; the time and value columns are found by name heuristics, so
the common exporter layouts work without configuration.

## Usage

``` r
readHealthConnect(path, tz = "UTC")
```

## Arguments

- path:

  Directory of the CSV export (searched recursively), or a file / vector
  of files.

- tz:

  Time zone for parsed timestamps (default `"UTC"`).

## Value

A `health_connect` object: a list with any of `heart_rate`, `steps`,
`spo2`, `respiratory_rate` (`time`, `value`), and `sleep` (stage
intervals `start`, `end`, `stage`), plus `path`/`tz`. `spo2` feeds
`PhysioWearable::spo2Metrics()`, `sleep` feeds
`PhysioWearable::summarizeSleepStages()`.

## References

Android Health Connect data types and export.

## See also

[`readGoogleFit()`](https://x-biosignal.github.io/PhysioDevices/reference/readGoogleFit.md),
[`readFitbit()`](https://x-biosignal.github.io/PhysioDevices/reference/readFitbit.md)

## Examples

``` r
if (FALSE) { # \dontrun{
hc <- readHealthConnect("health_connect_export", tz = "Asia/Tokyo")
hc
PhysioWearable::spo2Metrics(hc$spo2$value, time = hc$spo2$time)
} # }
```
