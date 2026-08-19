# Read a Google Fit (Google Takeout) export

Parses the "Fit" folder of a Google Takeout archive. From "All Data" it
reads the granular per-type JSON points – heart rate (`heart_rate.bpm`)
and steps (`step_count.delta`) – decoding their nanosecond timestamps;
from "Daily activity metrics" it reads the daily-summary CSVs (steps,
calories, distance, average/max/min heart rate).

## Usage

``` r
readGoogleFit(path, what = NULL, tz = "UTC")
```

## Arguments

- path:

  Directory of the extracted Takeout "Fit" folder (searched
  recursively), or a file / vector of files.

- what:

  Optional restriction, any of `"heart_rate"`, `"steps"`, `"daily"`.

- tz:

  Time zone for parsed timestamps (default `"UTC"`).

## Value

A `google_fit` object: a list with any of `heart_rate`, `steps` (`time`,
`value`) and `daily` (per-day summary), plus `path`/`tz`.

## References

Google Takeout "Fit" export; Google Fit data types.

## See also

[`readHealthConnect()`](https://x-biosignal.github.io/PhysioDevices/reference/readHealthConnect.md),
[`readFitbit()`](https://x-biosignal.github.io/PhysioDevices/reference/readFitbit.md)

## Examples

``` r
if (FALSE) { # \dontrun{
gf <- readGoogleFit("Takeout/Fit", tz = "Asia/Tokyo")
gf$heart_rate
} # }
```
