# Build a PhysioExperiment from one numeric Apple Health modality

Apple Health samples are irregularly spaced, so the returned experiment
is event-like: a single channel holding the values, `samplingRate` `NA`,
and the per-sample timestamps stored in `metadata(pe)$times`.

## Usage

``` r
appleHealthExperiment(x, type)
```

## Arguments

- x:

  An `apple_health` object from
  [`readAppleHealth()`](https://x-biosignal.github.io/PhysioDevices/reference/readAppleHealth.md).

- type:

  A numeric record type (e.g. `"HeartRate"`, `"OxygenSaturation"`).

## Value

A `PhysioExperiment` with one channel of the modality's values.

## See also

[`appleHealthSeries()`](https://x-biosignal.github.io/PhysioDevices/reference/appleHealthSeries.md)
