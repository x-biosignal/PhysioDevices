# PhysioDevices: Wearable and Lab-System Device Ingestion for PhysioExperiment Objects

Readers that ingest consumer-wearable and wired laboratory device
exports into PhysioExperiment / MultiRatePhysioExperiment objects.
Wearables: Empatica E4 CSV sessions and EmbracePlus Avro containers
(multi-rate ACC / BVP / EDA / TEMP / HR / IBI streams), Shimmer GSR3+
Consensys exports (GSR, PPG, accelerometer), and Polar heart-rate / R-R
interval exports. Lab systems: BIOPAC AcqKnowledge '.acq' files
(per-channel rates and markers), Delsys Trigno EMG + IMU exports
(multi-rate streams with per-sensor metadata), and Xsens MVNX
motion-capture XML (segment kinematics, joint angles, centre of mass).
Each import records a provenance entry and the correct per-signal
sampling rates.

## See also

Useful links:

- <https://github.com/x-biosignal/PhysioDevices>

- <https://x-biosignal.r-universe.dev/PhysioDevices>

- <https://x-biosignal.github.io/PhysioDevices/>

- Report bugs at <https://github.com/x-biosignal/PhysioDevices/issues>

## Author

**Maintainer**: Yusuke Matsui <mail.to.matsui@gmail.com>
