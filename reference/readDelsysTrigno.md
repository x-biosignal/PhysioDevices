# Read a Delsys Trigno CSV export

Parses a Delsys Trigno File Utility / EMGworks CSV export into a
[PhysioCore::MultiRatePhysioExperiment](https://x-biosignal.r-universe.dev/PhysioCore/reference/MultiRatePhysioExperiment.html).
EMG channels (high rate) and the IMU channels (accelerometer / gyroscope
/ magnetometer, lower rate) are separated into their own streams, each
at the rate implied by its per-channel `X[s]` time column, with
per-sensor column metadata (sensor number and modality).

## Usage

``` r
readDelsysTrigno(path, sep = ",")
```

## Arguments

- path:

  Path to a Trigno `.csv` export.

- sep:

  Field separator (default: comma).

## Value

A
[PhysioCore::MultiRatePhysioExperiment](https://x-biosignal.r-universe.dev/PhysioCore/reference/MultiRatePhysioExperiment.html)
with an `"emg"` stream and, when present, an `"imu"` stream.

## References

Delsys. "Trigno File Utility / EMGworks export."

## See also

[`readXsensMVNX()`](https://x-biosignal.github.io/PhysioDevices/reference/readXsensMVNX.md),
[`readBIOPAC()`](https://x-biosignal.github.io/PhysioDevices/reference/readBIOPAC.md)

## Examples

``` r
f <- system.file("extdata", "delsys_trigno.csv", package = "PhysioDevices")
if (nzchar(f)) {
  mr <- readDelsysTrigno(f)
  PhysioCore::streamNames(mr)
}
#> [1] "emg" "imu"
```
