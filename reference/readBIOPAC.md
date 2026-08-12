# Read a BIOPAC AcqKnowledge (.acq) file

Parses a BIOPAC AcqKnowledge `.acq` file (via the Python `bioread`
module through reticulate; see
[`hasBioread()`](https://x-biosignal.github.io/PhysioDevices/reference/hasBioread.md))
into a
[PhysioCore::MultiRatePhysioExperiment](https://x-biosignal.r-universe.dev/PhysioCore/reference/MultiRatePhysioExperiment.html).
Each acquisition channel becomes a stream at its own sample rate
(channels may be acquired at different rates via frequency dividers),
carrying its label and unit. Event markers become
[PhysioCore::PhysioEvents](https://x-biosignal.r-universe.dev/PhysioCore/reference/PhysioEvents.html)
on the fastest stream.

## Usage

``` r
readBIOPAC(path)
```

## Arguments

- path:

  Path to a `.acq` file.

## Value

A
[PhysioCore::MultiRatePhysioExperiment](https://x-biosignal.r-universe.dev/PhysioCore/reference/MultiRatePhysioExperiment.html).

## References

bioread: <https://github.com/uwmadison-chm/bioread>.

## See also

[`hasBioread()`](https://x-biosignal.github.io/PhysioDevices/reference/hasBioread.md),
[`readDelsysTrigno()`](https://x-biosignal.github.io/PhysioDevices/reference/readDelsysTrigno.md),
[`readXsensMVNX()`](https://x-biosignal.github.io/PhysioDevices/reference/readXsensMVNX.md)
