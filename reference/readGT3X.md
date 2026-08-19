# Read an ActiGraph GT3X accelerometer file

Reads a raw ActiGraph `.gt3x` file (the common US physical-activity /
actigraphy device format) into a tri-axial-acceleration
`PhysioExperiment`. The binary decode is done by the read.gt3x package;
the result is the same shape as
`PhysioWearable::accelToPhysioExperiment()`, so it feeds the free-living
accelerometry pipeline (`computeENMO()`, `summarizeFreeLiving()`).

## Usage

``` r
readGT3X(path, imputeZeroes = TRUE)
```

## Arguments

- path:

  Path to a `.gt3x` file.

- imputeZeroes:

  If `TRUE` (default) idle-sleep-mode gaps are filled with zeroes
  (passed to
  [`read.gt3x::read.gt3x()`](https://rdrr.io/pkg/read.gt3x/man/read.gt3x.html))
  so the series stays regularly sampled.

## Value

A `PhysioExperiment` with an `acceleration` assay (x/y/z, g) at the
device sample rate; device metadata in `metadata()`.

## References

ActiGraph GT3X format; Neishabouri A et al. read.gt3x.

## See also

[`readCWA()`](https://x-biosignal.github.io/PhysioDevices/reference/readCWA.md),
`PhysioWearable::readAccelCSV()`

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readGT3X("subject.gt3x")
acc <- SummarizedExperiment::assay(pe, "acceleration")
PhysioWearable::computeENMO(acc, sampling_rate = samplingRate(pe))
} # }
```
