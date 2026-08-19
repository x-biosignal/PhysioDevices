# Research accelerometers: ActiGraph and Axivity

``` r

library(PhysioDevices)
#> Loading required package: PhysioCore
```

[`readGT3X()`](https://x-biosignal.github.io/PhysioDevices/reference/readGT3X.md)
and
[`readCWA()`](https://x-biosignal.github.io/PhysioDevices/reference/readCWA.md)
read the two field-standard raw research accelerometers – **ActiGraph**
(`.gt3x`, common in US cohorts) and **Axivity AX3/AX6** (`.cwa`, used by
UK Biobank and other large studies) – into the same
tri-axial-acceleration `PhysioExperiment` that
`PhysioWearable::readAccelCSV()` produces, so they flow straight into
the free-living pipeline.

The binary decode is delegated to the validated `read.gt3x` and
`GGIRread` packages (install them first); the readers only adapt the
result.

``` r

pe <- readGT3X("subject.gt3x")          # or readCWA("subject.cwa")
pe                                       # a PhysioExperiment: acceleration (x/y/z, g)
samplingRate(pe)
```

## Free-living metrics

The acceleration assay feeds ENMO, non-wear/calibration, intensity and
the free-living summary exactly as for `readAccelCSV()` output:

``` r

acc  <- SummarizedExperiment::assay(pe, "acceleration")
enmo <- PhysioWearable::computeENMO(acc, sampling_rate = samplingRate(pe))
PhysioWearable::summarizeFreeLiving(enmo)          # wear time, MVPA, intensity gradient, ...
```

## Notes

- `read.gt3x` / `GGIRread` are `Suggests` – each reader errors with an
  install hint if its package is missing.
- [`readCWA()`](https://x-biosignal.github.io/PhysioDevices/reference/readCWA.md)
  reads the whole file by default; pass `start`/`end` (block range) to
  read a long recording in pieces.
- These devices record **raw acceleration only** (no HR/SpO2); pair them
  with a smartwatch reader for those signals.
