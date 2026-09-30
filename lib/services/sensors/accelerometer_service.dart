import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'vector3_reading.dart';

/// Accelerometer service - provides acceleration data (m/s², gravity included).
/// Its only consumer is SensorViewModel's accelX/Y/Z + magnitude, shown on the
/// sensor card and read by the vibration analyzer; the G-force meter only gates
/// on the availability flag it sets. Not the compass or the spirit level:
/// OrientationService subscribes to `accelerometerEventStream()` itself and
/// feeds both, and never reads this service.
class AccelerometerService {
  static final AccelerometerService _instance =
      AccelerometerService._internal();
  factory AccelerometerService() => _instance;
  AccelerometerService._internal();

  StreamSubscription<AccelerometerEvent>? _subscription;
  // The controller owns the platform subscription: it starts on the first
  // listener and stops on the last. Subscribing IS starting, cancelling IS
  // stopping, so one consumer can never cut off another consumer's data.
  late final _controller = StreamController<Vector3Reading>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );
  // 5 Hz — the pre-refactor effective rate (the old 100 ms Timer throttle never
  // bound, the stream default was already 200 ms). SensorViewModel buffers 100
  // graph points per raw event, so this keeps the chart span at ~20 s.
  static const _samplingPeriod = SensorInterval.normalInterval; // 200 ms

  /// Stream of accelerometer data with magnitude
  Stream<Vector3Reading> get stream => _controller.stream;

  void _start() {
    _subscription = accelerometerEventStream(samplingPeriod: _samplingPeriod)
        .listen(
          (AccelerometerEvent event) {
            _controller.add(Vector3Reading(event.x, event.y, event.z));
          },
          onError: (error) {
            debugPrint('Accelerometer error: $error');
          },
        );
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
