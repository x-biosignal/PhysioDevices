# Summarise the record types in an Apple Health export

Summarise the record types in an Apple Health export

## Usage

``` r
appleHealthTypes(x)
```

## Arguments

- x:

  An `apple_health` object from
  [`readAppleHealth()`](https://x-biosignal.github.io/PhysioDevices/reference/readAppleHealth.md).

## Value

A data frame with one row per `type`: `n`, `unit`, and the time
`from`/`to`.

## See also

[`readAppleHealth()`](https://x-biosignal.github.io/PhysioDevices/reference/readAppleHealth.md),
[`appleHealthSeries()`](https://x-biosignal.github.io/PhysioDevices/reference/appleHealthSeries.md)
