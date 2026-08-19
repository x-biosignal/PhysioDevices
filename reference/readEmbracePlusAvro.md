# Read an Empatica EmbracePlus Avro container

Decodes an EmbracePlus `.avro` file into a
[PhysioCore::MultiRatePhysioExperiment](https://x-biosignal.github.io/PhysioCore//reference/MultiRatePhysioExperiment.html).
Each signal in the record's `rawData` (EDA, BVP, temperature,
accelerometer) becomes a stream at its `samplingFrequency`, aligned by
its `timestampStart` (microseconds). Requires an Avro backend (the
Python `fastavro` module via reticulate; see
[`hasAvroBackend()`](https://x-biosignal.github.io/PhysioDevices/reference/hasAvroBackend.md)).

## Usage

``` r
readEmbracePlusAvro(path)
```

## Arguments

- path:

  Path to an EmbracePlus `.avro` file.

## Value

A
[PhysioCore::MultiRatePhysioExperiment](https://x-biosignal.github.io/PhysioCore//reference/MultiRatePhysioExperiment.html).

## References

Empatica. "EmbracePlus — Avro data format."

## See also

[`readEmpaticaE4()`](https://x-biosignal.github.io/PhysioDevices/reference/readEmpaticaE4.md),
[`hasAvroBackend()`](https://x-biosignal.github.io/PhysioDevices/reference/hasAvroBackend.md)
