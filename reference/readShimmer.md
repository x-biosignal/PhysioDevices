# Read a Shimmer GSR3+ Consensys CSV export

Reads a Shimmer GSR3+ Consensys export (GSR / skin conductance, PPG,
accelerometer) into a `PhysioExperiment`. The calibrated (`_CAL`)
columns are read in their physical units; the timestamp column
determines the sampling rate; and each channel's unit (from the export's
unit row) is stored in the column metadata.

## Usage

``` r
readShimmer(path, sep = NULL)
```

## Arguments

- path:

  Path to a Shimmer Consensys `.csv` file.

- sep:

  Field separator. By default it is taken from a leading `sep=<char>`
  line, falling back to a tab.

## Value

A `PhysioExperiment` with one channel per calibrated signal.

## References

Shimmer. "Consensys — data export format."

## See also

[`readEmpaticaE4()`](https://x-biosignal.github.io/PhysioDevices/reference/readEmpaticaE4.md),
[`readPolar()`](https://x-biosignal.github.io/PhysioDevices/reference/readPolar.md)

## Examples

``` r
f <- system.file("extdata", "shimmer_gsr3.csv", package = "PhysioDevices")
if (nzchar(f)) {
  pe <- readShimmer(f)
  channelNames(pe)
}
#> [1] "GSR_Skin_Conductance" "PPG_A13"              "Accel_LN_X"          
#> [4] "Accel_LN_Y"           "Accel_LN_Z"          
```
