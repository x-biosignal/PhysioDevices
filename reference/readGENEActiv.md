# Read a GENEActiv .bin accelerometer file

Reads a raw GENEActiv `.bin` file (another research accelerometer used
in large cohorts) into a tri-axial-acceleration `PhysioExperiment`, in
the same shape as
[`readGT3X()`](https://x-biosignal.github.io/PhysioDevices/reference/readGT3X.md)
/
[`readCWA()`](https://x-biosignal.github.io/PhysioDevices/reference/readCWA.md),
via the GGIRread package.

## Usage

``` r
readGENEActiv(path, start = 1, end = NULL, sampling_rate = NULL)
```

## Arguments

- path:

  Path to a `.bin` file.

- start, end:

  Page range to read (1-based). `end = NULL` (default) reads the whole
  file.

- sampling_rate:

  Optional sample-rate override (Hz), used when the header does not
  report it; otherwise taken from the header or the timestamps.

## Value

A `PhysioExperiment` with an `acceleration` assay (x/y/z, g).

## References

GENEActiv; GGIRread::readGENEActiv.

## See also

[`readCWA()`](https://x-biosignal.github.io/PhysioDevices/reference/readCWA.md),
[`readGT3X()`](https://x-biosignal.github.io/PhysioDevices/reference/readGT3X.md)

## Examples

``` r
if (FALSE) { # \dontrun{
pe <- readGENEActiv("subject.bin")
} # }
```
