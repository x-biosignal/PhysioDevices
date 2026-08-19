# Extract one modality's samples from an Apple Health export

Extract one modality's samples from an Apple Health export

## Usage

``` r
appleHealthSeries(x, type)
```

## Arguments

- x:

  An `apple_health` object from
  [`readAppleHealth()`](https://x-biosignal.github.io/PhysioDevices/reference/readAppleHealth.md).

- type:

  A (prefix-stripped) record type, e.g. `"HeartRate"`,
  `"HeartRateVariabilitySDNN"`, `"OxygenSaturation"`, `"SleepAnalysis"`.

## Value

A data frame of that type's records (`start`, `end`, `value`,
`value_num`, `unit`, `source`), time-ordered.

## See also

[`appleHealthTypes()`](https://x-biosignal.github.io/PhysioDevices/reference/appleHealthTypes.md),
[`appleHealthExperiment()`](https://x-biosignal.github.io/PhysioDevices/reference/appleHealthExperiment.md)
