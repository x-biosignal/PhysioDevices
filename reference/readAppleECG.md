# Read an Apple Watch ECG recording

Parses the single-lead ECG CSV that the Apple Watch ECG app exports into
a `PhysioExperiment` (one `ECG` channel). The classification, recorded
date and sample rate from the file header are kept in `metadata()`. The
result feeds the `PhysioECG` beat-detection and heart-rate-variability
functions.

## Usage

``` r
readAppleECG(path, default_rate = 512)
```

## Arguments

- path:

  Path to an Apple Watch ECG `.csv` export.

- default_rate:

  Sample rate (Hz) to assume if the header has none (default 512, the
  Apple Watch ECG rate).

## Value

A `PhysioExperiment` with a `raw` assay of the ECG voltage (microvolts)
and `samplingRate` set from the header.

## References

Apple Inc. Taking an ECG with the ECG app on Apple Watch.

## See also

[`readAppleHealth()`](https://x-biosignal.github.io/PhysioDevices/reference/readAppleHealth.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ecg <- readAppleECG("ecg_2023-05-01.csv")
samplingRate(ecg)
} # }
```
