# Read a Polar heart-rate / R-R interval export

Reads a Polar (Flow / H10) export into a `PhysioExperiment`. A
heart-rate column (bpm) becomes the `"raw"` assay; R-R intervals (ms)
are attached as
[PhysioCore::PhysioEvents](https://x-biosignal.r-universe.dev/PhysioCore/reference/PhysioEvents.html)
(one event per beat, with onset at the cumulative R-R time and the
interval in the value). When only R-R intervals are present,
instantaneous heart rate (60000 / R-R) is used as the signal.

## Usage

``` r
readPolar(path, sep = ",")
```

## Arguments

- path:

  Path to a Polar `.csv`/`.txt` export.

- sep:

  Field separator (default: comma).

## Value

A `PhysioExperiment`; R-R intervals are available via
[`PhysioCore::getEvents()`](https://x-biosignal.r-universe.dev/PhysioCore/reference/getEvents.html).

## References

Polar. "Flow / H10 heart-rate and R-R export."

## See also

[`readEmpaticaE4()`](https://x-biosignal.github.io/PhysioDevices/reference/readEmpaticaE4.md),
[`readShimmer()`](https://x-biosignal.github.io/PhysioDevices/reference/readShimmer.md)

## Examples

``` r
f <- system.file("extdata", "polar_hr.csv", package = "PhysioDevices")
if (nzchar(f)) {
  pe <- readPolar(f)
  PhysioCore::nEvents(PhysioCore::getEvents(pe))
}
#> [1] 5
```
