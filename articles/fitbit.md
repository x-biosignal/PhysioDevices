# Analysing Fitbit and Google Pixel data

``` r

library(PhysioDevices)
#> Loading required package: PhysioCore
```

Fitbit exports your data as an account archive (Settings → *Export Your
Account Archive*) or as the Fitbit slice of **Google Takeout** — a
directory of per-day JSON (and some CSV) files. **Google Pixel Watch
stores its health data in Fitbit**, so the same reader covers Pixel
Watch. The analysis then reuses the same `PhysioWearable` / `PhysioECG`
functions as the Apple Watch workflow.

## 1. Ingest the archive

``` r

fb <- readFitbit("Takeout/Fitbit", tz = "Asia/Tokyo")
fb   # which modalities were found, with row counts and spans
```

[`readFitbit()`](https://x-biosignal.github.io/PhysioDevices/reference/readFitbit.md)
discovers files by name (`heart_rate-*`, `steps-*`, `sleep-*`,
`resting_heart_rate-*`, SpO2), parses the nested JSON, and skips
anything it cannot read (with a warning). Restrict with `what =` if you
only need some modalities.

## 2. Heart rate

``` r

hr <- fitbitSeries(fb, "heart_rate")     # columns: time, bpm (intraday)
summary(hr$bpm)
fb$resting_heart_rate                    # daily resting HR
```

For HRV, Fitbit exports its own daily RMSSD (a `Heart Rate Variability`
file); for beat-to-beat HRV use a Fitbit Sense/Charge ECG recording with
`PhysioECG`.

## 3. Blood oxygen (SpO2)

``` r

PhysioWearable::spo2Metrics(fb$spo2$value, time = fb$spo2$time)
```

## 4. Sleep

Fitbit scores sleep stages itself (`wake`/`light`/`deep`/`rem`).
`summarizeSleepStages()` turns them into per-night clinical metrics —
the same engine used for Apple Watch, just with Fitbit’s stage labels:

``` r

PhysioWearable::summarizeSleepStages(
  fb$sleep,
  asleep_levels = c("light", "deep", "rem"),
  wake_levels   = "wake",
  stage_cols    = c(light = "light", deep = "deep", rem = "rem"))

fb$sleep_summary          # Fitbit's own per-log efficiency / minutes asleep / time in bed
```

## 5. Activity

``` r

steps <- fitbitSeries(fb, "steps")
tapply(steps$value, as.Date(steps$time), sum)     # steps per day
```

For epoch-level free-living metrics (ENMO, intensity, fragmentation, HAR
→ ICF) you need raw accelerometry, which Fitbit does not export — only
derived activity.

## Scope and limitations

- Covers the Fitbit **account archive / Google Takeout** JSON layout;
  exact filenames vary slightly by export version (the reader keys off
  filename patterns and skips what it cannot parse).
- The Fitbit **Web API** (OAuth2, live JSON) is a separate path not
  covered here.
- **Google Pixel Watch** = Fitbit data (this reader). Phone-level Google
  data (Google Fit / Health Connect) is a different export and not
  covered here.
- No raw acceleration and no continuous SpO2 (spot readings) — same
  limits as the Apple Watch workflow.
