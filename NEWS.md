# PhysioDevices 0.9.5

* Validated `readGoogleFit()`'s granular "All Data" JSON path against a **real**
  Google Takeout Fit export (the MIT-licensed `digitraceslab/niimpy` sample
  data) -- it parses correctly, no change needed. The real export writes
  `startTimeNanos` as an unquoted 19-digit integer and `fitValue` values as
  `{fpVal}`/`{intVal}`; a new offline regression test pins this unquoted-nanos
  format (the previous fixture only covered the quoted-string form). The
  real-data harness now also covers the
  granular path, so Google Fit is real-sample validated on both its daily-CSV
  and granular-JSON paths. Tests only; no behaviour change.

# PhysioDevices 0.9.4

* `readHealthConnect()` now reads the canonical HRV field
  `heartRateVariabilityMillis`; the previous heuristic (`rmssd`/`value`) matched
  neither the androidx field name nor a PascalCase exporter column, so a
  schema-conformant HRV export was silently dropped.
* Strengthened Health Connect **schema-conformance tests**
  (`test-io-healthconnect-schema.R`). Since no public real Health Connect export
  exists, the fixtures now reproduce the documented schema exactly -- the androidx
  record field names (`beatsPerMinute`, `count`, `percentage`, `rate`,
  `heartRateVariabilityMillis`, the full `SleepSessionRecord.StageType` enum) and
  the MyDataHelps exporter's real CSV layout (PascalCase `Time`/`BeatsPerMinute`/
  `StartTime`/`EndTime`/`Stage`, a leading `HealthConnectRecordKey`, `Metadata*`
  columns, ISO-8601 timestamps with ms+offset or a UTC `Z`) -- covering all eight
  sleep-stage types, RespiratoryRate, interval `StartTime`-not-`EndTime`
  handling, and time/value detection past leading metadata columns.

# PhysioDevices 0.9.3

* `readOura()` now reads **both** the Oura API v1 and v2 sleep layouts. It
  previously mixed the two -- reading the v1 stage field (`hypnogram_5min`) but
  the v2 nested HR/HRV structure -- so real **v1** exports errored (records
  wrapped in `{sleep:[...]}`, HR/HRV as flat `hr_5min`/`rmssd_5min` arrays) and
  real **v2** exports silently lost their sleep stages (`sleep_phase_5_min`) and
  crashed on a `null` `total_sleep_duration`. The reader now handles the record
  wrapper, phase field, and nested-vs-flat HR/HRV of each version, and maps
  `0`/`null` readings to `NA`.
* Found by validating `readOura()` (and `readGoogleFit()`) against real public
  samples -- the `lildude/oura` v1/v2 API fixtures and a real Google Fit "Daily
  activity metrics" export. `readGoogleFit`'s daily-CSV path and Apple Health's
  offset-aware timestamps were confirmed correct on real data. Offline
  regression tests added; the reproducible real-data harness now covers Apple, Fitbit, Oura and Google Fit.

# PhysioDevices 0.9.2

* `readFitbit()` now reads the **aggregated Web-API export layout** in addition
  to the per-day account archive. Fitbit's Web-API / research extraction (e.g.
  the PMData dataset) writes one file per modality (`heart_rate.json`,
  `steps.json`, `sleep.json`) with no per-day date suffix; the previous
  filename patterns (`^heart_rate-`, `^steps-`, `^sleep-`) required the suffix
  and silently read only `resting_heart_rate`, dropping heart rate, steps and
  sleep. The patterns now match both layouts (`^heart_rate[-.]`, ...), while
  still keeping `resting_heart_rate` out of `heart_rate` and `sleep_score.csv`
  out of the sleep stages.
* Found by validating `readAppleHealth()` and `readFitbit()` against real public
  sample exports (Apple: the MIT `tdda/applehealthdata` sample; Fitbit: the
  PMData dataset). Apple Health's offset-aware timestamp handling was confirmed
  correct on real data. Offline regression tests added
  (`test-io-realdata-variants.R`); the reproducible real-data validation is maintained separately.

# PhysioDevices 0.9.1

* `readFIT()` now maps FIT "invalid" sentinels to `NA` -- a missing reading is
  stored as the base type's maximum (heart rate / cadence `255`, power `65535`),
  which previously passed through as impossible values (e.g. a ride recorded
  without a heart-rate strap read as a constant 255 bpm). Found by validating
  against the real Garmin/ANT+ `.fit` files bundled with `FITfileR`
  (`garmin-edge530-ride.fit`, `garmin-fenix6-swim.fit`), which are now used as
  end-to-end reader tests.

# PhysioDevices 0.9.0

Native Garmin FIT, plus Whoop, Withings and Samsung Health.

* `readFIT()` reads a Garmin/ANT+ `.fit` workout file (Garmin, Wahoo, Coros, ...)
  into the same tidy trackpoint data frame as `readTCX()` / `readGPX()`. The
  binary decode is delegated to the `FITfileR` package (not on CRAN -- install
  from `https://grimbough.r-universe.dev`, added to `Additional_repositories`),
  closing the native-`.fit` gap left by the workout/GPS readers.
* `readWhoop()` parses a Whoop CSV export into tidy daily summaries: `sleep`
  (stage durations, efficiency, HRV, respiratory rate) and `recovery` (recovery
  score, resting heart rate, HRV, blood oxygen, skin temperature). Whoop exports
  summaries, not epoch-level stages.
* `readWithings()` parses a Withings Health Mate export (ScanWatch / Sleep / BPM
  / Body) into tidy `heart_rate`, `spo2`, `blood_pressure` and `weight` tables.
* `readSamsungHealth()` parses a Samsung Health / Galaxy Watch export
  (`com.samsung...` CSVs, each with a one-line metadata comment above the header)
  into `heart_rate`, `spo2` and `steps` series, handling both ISO and
  epoch-millisecond timestamps.
* All four reuse the device-agnostic analysis layer (`spo2Metrics()`,
  `summarizeSleep()`, the `PhysioECG` HRV path).

# PhysioDevices 0.8.0

GENEActiv and Actiwatch (research accelerometry / clinical actigraphy).

* `readGENEActiv()` reads a GENEActiv `.bin` file into the tri-axial-acceleration
  `PhysioExperiment` (via `GGIRread`), completing the raw research-accelerometer
  set (ActiGraph, Axivity, GENEActiv). A `sampling_rate` override is available
  for files whose header does not report the rate.
* `readActiwatch()` reads a Philips/Respironics Actiwatch `.awd` file into
  per-epoch activity counts with timestamps, feeding
  `PhysioWearable::coleKripke()` / `summarizeSleep()`. The start date is parsed
  locale-independently; the epoch is a parameter (the `.awd` header does not
  carry it reliably).

# PhysioDevices 0.7.0

Workout / GPS (Garmin, Strava, ...) and Oura Ring.

* `readTCX()` and `readGPX()` read workout / GPS track files (the common Garmin
  Connect, Strava, Apple and Google export) into a tidy trackpoint data frame --
  time, position, altitude, distance, heart rate, cadence/speed -- using
  namespace-robust XPath. This is the practical path for Garmin (whose raw binary
  `.fit` needs the GitHub-only FITfileR) and closes the workout/GPS gap in the
  Apple/Google readers.
* `readOura()` reads an Oura Ring sleep export (API v2 JSON): the 5-minute
  hypnogram is expanded to sleep-stage intervals (feeding
  `PhysioWearable::summarizeSleepStages()`), alongside the 5-minute heart-rate and
  HRV (RMSSD) series and Oura's own sleep summary.

# PhysioDevices 0.6.0

Research-grade raw accelerometers.

* `readGT3X()` reads an ActiGraph `.gt3x` file and `readCWA()` an Axivity AX3/AX6
  `.cwa` file (the physical-activity / accelerometry field standards in US and UK
  cohorts) into the ecosystem's tri-axial-acceleration `PhysioExperiment` -- the
  same shape as `PhysioWearable::readAccelCSV()`, so they feed `computeENMO()` /
  `summarizeFreeLiving()` directly. The binary decode is delegated to the
  validated `read.gt3x` / `GGIRread` packages (new `Suggests`).
* New vignette `research-accelerometers`.

# PhysioDevices 0.5.1

Fixes to the Google Fit / Health Connect readers (from a code review of 0.5.0).

* **Timezone**: `.iso_time` is now offset-aware -- a trailing `Z` or a numeric
  offset (`+09:00`) is parsed as an absolute instant, so timestamps are no longer
  wrong by the offset (previously e.g. a `...Z` value under `tz="Asia/Tokyo"` was
  9 h off).
* `readGoogleFit()` no longer aborts on a data point with an empty `fitValue`
  (it becomes `NA`), re-sorts heart-rate/step series across source files, warns
  on unreadable files, and handles a nanosecond value that arrives unquoted.
* `readHealthConnect()` routes `HeartRateVariability*` to its own `hrv` modality
  (no longer mixed into heart rate), skips unrecognised record types with a
  warning instead of inventing a modality from the last numeric column, avoids an
  interval `end` column as the sample time, no longer treats a `sessionType`
  column as the sleep stage, warns when a sleep `end` is missing, and builds each
  modality with a single `rbind`.
* The heart-rate column is named `bpm` in all three consumer readers.

# PhysioDevices 0.5.0

Google Fit and Android Health Connect ingestion.

* `readGoogleFit()` parses a Google Takeout "Fit" export: the granular per-type
  JSON under "All Data" (heart rate, steps; decoding the nanosecond timestamps)
  and the "Daily activity metrics" summary CSVs.
* `readHealthConnect()` parses an Android Health Connect per-record-type CSV
  export (`HeartRate`, `Steps`, `OxygenSaturation`, `RespiratoryRate`,
  `SleepSession` stages), detecting the time/value columns heuristically since
  exporter layouts vary. `spo2` feeds `PhysioWearable::spo2Metrics()` and `sleep`
  feeds `PhysioWearable::summarizeSleepStages()`.
* The `fitbit` vignette now also shows the Google Fit / Health Connect paths.

# PhysioDevices 0.4.0

Fitbit / Google Pixel ingestion.

* `readFitbit()` parses a Fitbit account archive or Google Takeout directory
  (per-day JSON, plus SpO2 CSV) into tidy per-modality series -- heart rate,
  steps, SpO2, resting heart rate -- and sleep-stage intervals plus Fitbit's own
  per-log sleep summary. Files are discovered by name and unreadable ones are
  skipped with a warning. Google Pixel Watch health data is stored in Fitbit, so
  the same reader covers it.
* `fitbitSeries()` extracts one modality. The `sleep` stages feed
  `PhysioWearable::summarizeSleepStages()` and `spo2` feeds
  `PhysioWearable::spo2Metrics()`.
* New vignette `fitbit`. Requires the `jsonlite` package.

# PhysioDevices 0.3.0

Apple Watch / Apple Health ingestion.

* `readAppleHealth()` streams an Apple Health `export.xml` into a tidy
  `apple_health` object: every `<Record>` (heart rate, `HeartRateVariabilitySDNN`,
  `OxygenSaturation`, respiratory rate, step count, energy, resting/walking heart
  rate, VO2 max, and `SleepAnalysis` sleep stages) becomes a row, and `<Workout>`
  elements a workout table. The Apple type prefixes are stripped and timestamps
  parsed; large exports are handled without loading the whole file.
* `appleHealthTypes()`, `appleHealthSeries()` and `appleHealthExperiment()`
  summarise the available modalities, pull one modality's samples, and build a
  (irregular) `PhysioExperiment` from a numeric modality.
* `readAppleECG()` reads the Apple Watch single-lead ECG CSV export into a
  `PhysioExperiment` (voltage, sample rate and classification from the header),
  ready for the `PhysioECG` beat-detection / HRV functions.
* New vignette `apple-watch` walks an export through HR/HRV, SpO2, sleep,
  activity and ECG end to end.
