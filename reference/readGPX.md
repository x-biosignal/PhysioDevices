# Read a GPX (GPS Exchange) track file

Parses the track points of a `.gpx` file (a widely shared GPS/workout
export) into a tidy data frame: time, position, altitude, and heart rate
/ cadence when the Garmin TrackPointExtension is present.

## Usage

``` r
readGPX(path, tz = "UTC")
```

## Arguments

- path:

  Path to a `.gpx` file.

- tz:

  Time zone for the parsed timestamps (default `"UTC"`).

## Value

A data frame of track points (`time`, `lat`, `lon`, `altitude_m`, `hr`,
`cadence`), time-ordered.

## References

GPX 1.1 schema; Garmin TrackPointExtension.

## See also

[`readTCX()`](https://x-biosignal.github.io/PhysioDevices/reference/readTCX.md)

## Examples

``` r
if (FALSE) { # \dontrun{
tp <- readGPX("ride.gpx")
} # }
```
