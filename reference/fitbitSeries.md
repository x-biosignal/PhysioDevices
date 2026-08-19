# Extract one modality from a Fitbit archive

Extract one modality from a Fitbit archive

## Usage

``` r
fitbitSeries(x, modality)
```

## Arguments

- x:

  A `fitbit` object from
  [`readFitbit()`](https://x-biosignal.github.io/PhysioDevices/reference/readFitbit.md).

- modality:

  One of the modality names present in `x` (e.g. `"heart_rate"`,
  `"spo2"`, `"sleep"`).

## Value

The modality's data frame.

## See also

[`readFitbit()`](https://x-biosignal.github.io/PhysioDevices/reference/readFitbit.md)
