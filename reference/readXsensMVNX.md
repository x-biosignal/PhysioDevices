# Read an Xsens MVNX motion-capture export

Parses an Xsens MVN Analyze `.mvnx` XML file into a
[PhysioCore::MultiRatePhysioExperiment](https://x-biosignal.r-universe.dev/PhysioCore/reference/MultiRatePhysioExperiment.html).
Each kinematic signal present in the "normal" frames (segment position,
orientation, velocity, acceleration, angular velocity/acceleration,
per-joint angles, and centre of mass) becomes a stream at the subject
frame rate, with per-channel labels built from the segment/joint names.

## Usage

``` r
readXsensMVNX(path)
```

## Arguments

- path:

  Path to a `.mvnx` file.

## Value

A
[PhysioCore::MultiRatePhysioExperiment](https://x-biosignal.r-universe.dev/PhysioCore/reference/MultiRatePhysioExperiment.html).

## References

Xsens. "MVNX file format (MVN Analyze)."

## See also

[`readBIOPAC()`](https://x-biosignal.github.io/PhysioDevices/reference/readBIOPAC.md),
[`readDelsysTrigno()`](https://x-biosignal.github.io/PhysioDevices/reference/readDelsysTrigno.md)

## Examples

``` r
f <- system.file("extdata", "xsens_sample.mvnx", package = "PhysioDevices")
if (nzchar(f) && requireNamespace("xml2", quietly = TRUE)) {
  mr <- readXsensMVNX(f)
  PhysioCore::streamNames(mr)
}
#> [1] "position"     "orientation"  "acceleration" "jointAngle"   "centerOfMass"
```
