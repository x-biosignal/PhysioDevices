# Read an Apple Health export

Parses an Apple Health `export.xml` into a tidy set of records and
workout summaries. Every sample Apple stores as a `<Record>` – heart
rate, heart-rate variability (`HeartRateVariabilitySDNN`), blood oxygen
(`OxygenSaturation`), respiratory rate, step count, active/basal energy,
resting and walking heart rate, VO2 max, and `SleepAnalysis` sleep
stages – becomes one row; `<Workout>` elements become the `workouts`
table. The reader streams the file, so multi- hundred-MB exports are
handled without loading the whole document into memory.

## Usage

``` r
readAppleHealth(path, types = NULL, tz = "UTC")
```

## Arguments

- path:

  Path to the Apple Health `export.xml`.

- types:

  Optional character vector of (prefix-stripped) record types to keep;
  `NULL` (default) keeps all.

- tz:

  Time zone for the parsed timestamps (default `"UTC"`).

## Value

An `apple_health` object: a list with `records` (a data frame with
`type`, `source`, `unit`, `start`, `end`, `value`, `value_num`),
`workouts` (or `NULL`), `path` and `tz`.

## Details

The Apple type prefix (`HKQuantityTypeIdentifier` /
`HKCategoryTypeIdentifier`) is stripped, so `type` reads e.g.
`"HeartRate"`, `"OxygenSaturation"`, `"SleepAnalysis"`. Numeric samples
are parsed into `value_num`; category samples (sleep stages) keep their
(prefix-stripped) label in `value`.

## References

Apple Inc. HealthKit data types and the Health app XML export.

## See also

[`appleHealthSeries()`](https://x-biosignal.github.io/PhysioDevices/reference/appleHealthSeries.md),
[`appleHealthTypes()`](https://x-biosignal.github.io/PhysioDevices/reference/appleHealthTypes.md),
[`appleHealthExperiment()`](https://x-biosignal.github.io/PhysioDevices/reference/appleHealthExperiment.md),
[`readAppleECG()`](https://x-biosignal.github.io/PhysioDevices/reference/readAppleECG.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ah <- readAppleHealth("apple_health_export/export.xml", tz = "Asia/Tokyo")
appleHealthTypes(ah)
hr <- appleHealthSeries(ah, "HeartRate")
} # }
```
