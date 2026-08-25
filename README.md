# PhysioDevices

[![r-universe](https://x-biosignal.r-universe.dev/badges/PhysioDevices)](https://x-biosignal.r-universe.dev/PhysioDevices)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`PhysioDevices` imports exports from supported wearable and laboratory systems
into `PhysioExperiment` or `MultiRatePhysioExperiment` objects. Native sampling
rates, device metadata, events, and import provenance are retained where the
source format provides them.

## Installation

```r
options(repos = c(
  xbiosignal = "https://x-biosignal.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))
install.packages("PhysioDevices")
```

## Quick start

The package includes a small Empatica E4 fixture:

```r
library(PhysioDevices)

session <- system.file("extdata", "e4_sample", package = "PhysioDevices")
recording <- readEmpaticaE4(session)

PhysioCore::streamNames(recording)
```

## Supported readers

| Source | Reader | Result |
|---|---|---|
| Empatica E4 CSV session | `readEmpaticaE4()` | Multi-rate recording |
| Empatica EmbracePlus Avro | `readEmbracePlusAvro()` | Multi-rate recording |
| Shimmer Consensys export | `readShimmer()` | Multi-rate recording |
| Polar HR/RR export | `readPolar()` | Recording with beat events |
| BIOPAC AcqKnowledge | `readBIOPAC()` | Multi-rate recording |
| Delsys Trigno | `readDelsysTrigno()` | Multi-rate EMG/IMU recording |
| Xsens MVNX | `readXsensMVNX()` | Motion-capture recording |

EmbracePlus and BIOPAC readers expose `hasAvroBackend()` and `hasBioread()` so
applications can check optional backends before importing.

## Ecosystem role

`PhysioDevices` is an acquisition adapter. Its outputs use the common
`PhysioCore` model and can move into preprocessing, modality-specific analysis,
cross-modal synchronization, or streaming workflows without a device-specific
container.

## Documentation

- [Function reference and vignettes](https://x-biosignal.r-universe.dev/PhysioDevices)
- [Source repository](https://github.com/x-biosignal/PhysioDevices)
- [Issue tracker](https://github.com/x-biosignal/PhysioDevices/issues)

## Citation

```r
citation("PhysioDevices")
```

See the ecosystem [governance](https://github.com/x-biosignal/PhysioExperiment/blob/main/GOVERNANCE.md),
[support policy](https://github.com/x-biosignal/PhysioExperiment/blob/main/SUPPORT.md),
and [contribution guide](https://github.com/x-biosignal/PhysioExperiment/blob/main/CONTRIBUTING.md).

## Author and license

Author and maintainer: **Yusuke Matsui**. Licensed under the [MIT License](LICENSE).
