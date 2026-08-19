# Changelog

## PhysioDevices 0.4.0

Fitbit / Google Pixel ingestion.

- [`readFitbit()`](https://x-biosignal.github.io/PhysioDevices/reference/readFitbit.md)
  parses a Fitbit account archive or Google Takeout directory (per-day
  JSON, plus SpO2 CSV) into tidy per-modality series – heart rate,
  steps, SpO2, resting heart rate – and sleep-stage intervals plus
  Fitbit’s own per-log sleep summary. Files are discovered by name and
  unreadable ones are skipped with a warning. Google Pixel Watch health
  data is stored in Fitbit, so the same reader covers it.
- [`fitbitSeries()`](https://x-biosignal.github.io/PhysioDevices/reference/fitbitSeries.md)
  extracts one modality. The `sleep` stages feed
  `PhysioWearable::summarizeSleepStages()` and `spo2` feeds
  `PhysioWearable::spo2Metrics()`.
- New vignette `fitbit`. Requires the `jsonlite` package.

## PhysioDevices 0.3.0

Apple Watch / Apple Health ingestion.

- [`readAppleHealth()`](https://x-biosignal.github.io/PhysioDevices/reference/readAppleHealth.md)
  streams an Apple Health `export.xml` into a tidy `apple_health`
  object: every `<Record>` (heart rate, `HeartRateVariabilitySDNN`,
  `OxygenSaturation`, respiratory rate, step count, energy,
  resting/walking heart rate, VO2 max, and `SleepAnalysis` sleep stages)
  becomes a row, and `<Workout>` elements a workout table. The Apple
  type prefixes are stripped and timestamps parsed; large exports are
  handled without loading the whole file.
- [`appleHealthTypes()`](https://x-biosignal.github.io/PhysioDevices/reference/appleHealthTypes.md),
  [`appleHealthSeries()`](https://x-biosignal.github.io/PhysioDevices/reference/appleHealthSeries.md)
  and
  [`appleHealthExperiment()`](https://x-biosignal.github.io/PhysioDevices/reference/appleHealthExperiment.md)
  summarise the available modalities, pull one modality’s samples, and
  build a (irregular) `PhysioExperiment` from a numeric modality.
- [`readAppleECG()`](https://x-biosignal.github.io/PhysioDevices/reference/readAppleECG.md)
  reads the Apple Watch single-lead ECG CSV export into a
  `PhysioExperiment` (voltage, sample rate and classification from the
  header), ready for the `PhysioECG` beat-detection / HRV functions.
- New vignette `apple-watch` walks an export through HR/HRV, SpO2,
  sleep, activity and ECG end to end.
