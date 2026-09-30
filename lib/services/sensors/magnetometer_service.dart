import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Magnetometer service - emits the magnetic field magnitude (µT) used by the
/// sensor card and the metal detector. It exposes no raw axes: OrientationService
/// subscribes to `magnetometerEventStream()` itself for the tilt-compensated
/// heading and the hard-iron calibration, and never reads this service.
class MagnetometerService {
  static final MagnetometerService _instance = MagnetometerService._internal();
  factory MagnetometerService() => _instance;
  MagnetometerService._internal();

  StreamSubscription<MagnetometerEvent>? _subscription;
  // Controller owns the platform subscription — see AccelerometerService.
  late final _controller = StreamController<double>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );
  // 5 Hz — the pre-refactor effective rate (the old 100 ms Timer throttle never
  // bound, the stream default was already 200 ms). SensorViewModel buffers 100
  // graph points per raw event, so this keeps the chart span at ~20 s.
  static const _samplingPeriod = SensorInterval.normalInterval; // 200 ms

  /// Stream of magnetometer field magnitude (µT - microtesla)
  Stream<double> get stream => _controller.stream;

  void _start() {
    _subscription = magnetometerEventStream(samplingPeriod: _samplingPeriod)
        .listen(
          (MagnetometerEvent event) {
            _controller.add(
              math.sqrt(
                event.x * event.x + event.y * event.y + event.z * event.z,
              ),
            );
          },
          onError: (error) {
            debugPrint('Magnetometer error: $error');
          },
        );
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
