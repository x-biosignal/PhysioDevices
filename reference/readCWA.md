# Read an Axivity AX3/AX6 CWA accelerometer file

Reads a raw Axivity `.cwa` file (the accelerometer format used by UK
Biobank and other large cohorts) into a tri-axial-acceleration
`PhysioExperiment` via the GGIRread package, in the same shape as
[`readGT3X()`](https://x-biosignal.github.io/PhysioDevices/reference/readGT3X.md)
/ `PhysioWearable::accelToPhysioExperiment()`.

## Usage

``` r
readCWA(path, start = 1, end = NULL)
```

## Arguments

- path:

  Path to a `.cwa` file.

- start, end:

  Block range to read (1-based). `end = NULL` (default) reads the whole
  file. For very long recordings, read in ranges.

## Value

A `PhysioExperiment` with an `acceleration` assay (x/y/z, g) at the
device sample rate.

## References

Axivity AX3/AX6; GGIRread::readAxivity.

## See also

[`readGT3X()`](https://x-biosignal.github.io/PhysioDevices/reference/readGT3X.md),
`PhysioWearable::readAccelCSV()`

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readCWA("subject.cwa")
acc <- SummarizedExperiment::assay(pe, "acceleration")
enmo <- PhysioWearable::computeENMO(acc, sampling_rate = samplingRate(pe))
} # }
```
