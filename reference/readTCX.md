# Read a TCX (Garmin Training Center) workout file

Parses the trackpoints of a `.tcx` workout (the common Garmin Connect /
Strava export) into a tidy data frame: time, position, altitude,
distance, heart rate and cadence/speed where present.

## Usage

``` r
readTCX(path, tz = "UTC")
```

## Arguments

- path:

  Path to a `.tcx` file.

- tz:

  Time zone for the parsed timestamps (default `"UTC"`).

## Value

A data frame of trackpoints (`time`, `lat`, `lon`, `altitude_m`,
`distance_m`, `hr`, `cadence`, `speed`), time-ordered, with the activity
`sport` in `attr(, "sport")`.

## References

Garmin Training Center XML (TCX) schema.

## See also

[`readGPX()`](https://x-biosignal.github.io/PhysioDevices/reference/readGPX.md),
[`readFitbit()`](https://x-biosignal.github.io/PhysioDevices/reference/readFitbit.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tp <- readTCX("run.tcx")
plot(tp$lon, tp$lat)     # the route
} # }
```
