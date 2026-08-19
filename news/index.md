# Changelog

## PhysioDevices 0.7.0

Workout / GPS (Garmin, Strava, …) and Oura Ring.

- [`readTCX()`](https://x-biosignal.github.io/PhysioDevices/reference/readTCX.md)
  and
  [`readGPX()`](https://x-biosignal.github.io/PhysioDevices/reference/readGPX.md)
  read workout / GPS track files (the common Garmin Connect, Strava,
  Apple and Google export) into a tidy trackpoint data frame – time,
  position, altitude, distance, heart rate, cadence/speed – using
  namespace-robust XPath. This is the practical path for Garmin (whose
  raw binary `.fit` needs the GitHub-only FITfileR) and closes the
  workout/GPS gap in the Apple/Google readers.
- [`readOura()`](https://x-biosignal.github.io/PhysioDevices/reference/readOura.md)
  reads an Oura Ring sleep export (API v2 JSON): the 5-minute hypnogram
  is expanded to sleep-stage intervals (feeding
  `PhysioWearable::summarizeSleepStages()`), alongside the 5-minute
  heart-rate and HRV (RMSSD) series and Oura’s own sleep summary.

## PhysioDevices 0.6.0

Research-grade raw accelerometers.

- [`readGT3X()`](https://x-biosignal.github.io/PhysioDevices/reference/readGT3X.md)
  reads an ActiGraph `.gt3x` file and
  [`readCWA()`](https://x-biosignal.github.io/PhysioDevices/reference/readCWA.md)
  an Axivity AX3/AX6 `.cwa` file (the physical-activity / accelerometry
  field standards in US and UK cohorts) into the ecosystem’s
  tri-axial-acceleration `PhysioExperiment` – the same shape as
  `PhysioWearable::readAccelCSV()`, so they feed `computeENMO()` /
  `summarizeFreeLiving()` directly. The binary decode is delegated to
  the validated `read.gt3x` / `GGIRread` packages (new `Suggests`).
- New vignette `research-accelerometers`.

## PhysioDevices 0.5.1

Fixes to the Google Fit / Health Connect readers (from a code review of
0.5.0).

- **Timezone**: `.iso_time` is now offset-aware – a trailing `Z` or a
  numeric offset (`+09:00`) is parsed as an absolute instant, so
  timestamps are no longer wrong by the offset (previously e.g. a `...Z`
  value under `tz="Asia/Tokyo"` was 9 h off).
- [`readGoogleFit()`](https://x-biosignal.github.io/PhysioDevices/reference/readGoogleFit.md)
  no longer aborts on a data point with an empty `fitValue` (it becomes
  `NA`), re-sorts heart-rate/step series across source files, warns on
  unreadable files, and handles a nanosecond value that arrives
  unquoted.
- [`readHealthConnect()`](https://x-biosignal.github.io/PhysioDevices/reference/readHealthConnect.md)
  routes `HeartRateVariability*` to its own `hrv` modality (no longer
  mixed into heart rate), skips unrecognised record types with a warning
  instead of inventing a modality from the last numeric column, avoids
  an interval `end` column as the sample time, no longer treats a
  `sessionType` column as the sleep stage, warns when a sleep `end` is
  missing, and builds each modality with a single `rbind`.
- The heart-rate column is named `bpm` in all three consumer readers.

## PhysioDevices 0.5.0

Google Fit and Android Health Connect ingestion.

- [`readGoogleFit()`](https://x-biosignal.github.io/PhysioDevices/reference/readGoogleFit.md)
  parses a Google Takeout “Fit” export: the granular per-type JSON under
  “All Data” (heart rate, steps; decoding the nanosecond timestamps) and
  the “Daily activity metrics” summary CSVs.
- [`readHealthConnect()`](https://x-biosignal.github.io/PhysioDevices/reference/readHealthConnect.md)
  parses an Android Health Connect per-record-type CSV export
  (`HeartRate`, `Steps`, `OxygenSaturation`, `RespiratoryRate`,
  `SleepSession` stages), detecting the time/value columns heuristically
  since exporter layouts vary. `spo2` feeds
  `PhysioWearable::spo2Metrics()` and `sleep` feeds
  `PhysioWearable::summarizeSleepStages()`.
- The `fitbit` vignette now also shows the Google Fit / Health Connect
  paths.

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
