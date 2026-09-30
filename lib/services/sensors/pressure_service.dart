import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Service for monitoring barometric pressure sensor
/// Singleton pattern ensures only one instance exists
class PressureService {
  static final PressureService _instance = PressureService._internal();
  factory PressureService() => _instance;
  PressureService._internal();

  StreamSubscription? _subscription;
  // Controller owns the platform subscription — see AccelerometerService.
  late final _controller = StreamController<double>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );

  Stream<double> get stream => _controller.stream;

  void _start() {
    _subscription = barometerEventStream().listen(
      (event) {
        // Pressure is in hectopascals (hPa) or millibars (mb)
        _controller.add(event.pressure);
      },
      onError: (error) {
        debugPrint('Pressure sensor error: $error');
        _controller.addError(error); // Propagate error to listeners
      },
    );
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
