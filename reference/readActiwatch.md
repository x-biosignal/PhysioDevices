# Read an Actiwatch AWD actigraphy file

Parses a Philips/Respironics Actiwatch `.awd` file into per-epoch
activity counts with timestamps. The start date/time is read from the
header; the activity counts are the longest run of numeric lines (the
data block).

## Usage

``` r
readActiwatch(path, epoch = 60, tz = "UTC")
```

## Arguments

- path:

  Path to a `.awd` file.

- epoch:

  Epoch length in seconds (default 60). The `.awd` header does not
  reliably carry it, so set it to your recording's epoch.

- tz:

  Time zone for the timestamps (default `"UTC"`).

## Value

A data frame with `time` (`POSIXct`) and `activity` (counts), with the
epoch length in `attr(, "epoch_sec")`. Feeds
`PhysioWearable::coleKripke()` (which expects 1-minute epochs).

## References

Philips Respironics Actiwatch / Actiware AWD format.

## See also

[`readGT3X()`](https://x-biosignal.github.io/PhysioDevices/reference/readGT3X.md),
[`readGENEActiv()`](https://x-biosignal.github.io/PhysioDevices/reference/readGENEActiv.md)

## Examples

``` r
if (FALSE) { # \dontrun{
aw <- readActiwatch("subject.awd", epoch = 60)
sw <- PhysioWearable::coleKripke(aw$activity)
} # }
```
