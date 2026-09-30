import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'vector3_reading.dart';

/// Service for monitoring gyroscope (angular velocity, rad/s)
/// Singleton pattern ensures only one instance exists
class GyroscopeService {
  static final GyroscopeService _instance = GyroscopeService._internal();
  factory GyroscopeService() => _instance;
  GyroscopeService._internal();

  StreamSubscription? _subscription;
  // Controller owns the platform subscription — see AccelerometerService.
  late final _controller = StreamController<Vector3Reading>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );
  // 5 Hz — the pre-refactor effective rate (the old 100 ms Timer throttle never
  // bound, the stream default was already 200 ms). SensorViewModel buffers 100
  // graph points per raw event, so this keeps the chart span at ~20 s.
  static const _samplingPeriod = SensorInterval.normalInterval; // 200 ms

  Stream<Vector3Reading> get stream => _controller.stream;

  void _start() {
    _subscription = gyroscopeEventStream(samplingPeriod: _samplingPeriod)
        .listen(
          (event) {
            _controller.add(Vector3Reading(event.x, event.y, event.z));
          },
          onError: (error) {
            debugPrint('Gyroscope error: $error');
          },
        );
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
