# Read an Empatica E4 CSV session directory

Reads an Empatica E4 session (a directory of per-signal CSV files) into
a
[PhysioCore::MultiRatePhysioExperiment](https://x-biosignal.github.io/PhysioCore//reference/MultiRatePhysioExperiment.html).
Each present signal (EDA at 4 Hz, BVP at 64 Hz, ACC at 32 Hz, TEMP at 4
Hz, HR at 1 Hz) becomes its own stream at its native rate, and the
per-signal UTC start times are aligned on a common clock via per-stream
offsets. Inter-beat intervals (`IBI.csv`) and event tags (`tags.csv`)
are attached as events.

## Usage

``` r
readEmpaticaE4(dir)
```

## Arguments

- dir:

  Path to an E4 session directory.

## Value

A
[PhysioCore::MultiRatePhysioExperiment](https://x-biosignal.github.io/PhysioCore//reference/MultiRatePhysioExperiment.html)
with one stream per signal.

## References

Empatica. "E4 wristband data — exported CSV file format."

## See also

[`readEmbracePlusAvro()`](https://x-biosignal.github.io/PhysioDevices/reference/readEmbracePlusAvro.md),
[`readShimmer()`](https://x-biosignal.github.io/PhysioDevices/reference/readShimmer.md)

## Examples

``` r
d <- system.file("extdata", "e4_sample", package = "PhysioDevices")
if (nzchar(d)) {
  mr <- readEmpaticaE4(d)
  PhysioCore::streamNames(mr)
}
#> [1] "eda"  "bvp"  "acc"  "temp" "hr"  
```
