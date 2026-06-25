import 'dart:async';
import 'dart:math' as dart_math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Service for monitoring barometric pressure sensor
/// Singleton pattern ensures only one instance exists
class PressureService {
  static final PressureService _instance = PressureService._internal();
  factory PressureService() => _instance;
  PressureService._internal();

  StreamSubscription? _subscription;
  final _controller = StreamController<double>.broadcast();

  Stream<double> get stream => _controller.stream;
  double? _currentPressure;

  /// Start listening to pressure sensor
  Future<void> startListening() async {
    // Stop any existing subscription first
    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    _subscription = barometerEventStream().listen(
      (event) {
        // Pressure is in hectopascals (hPa) or millibars (mb)
        _currentPressure = event.pressure;
        _controller.add(_currentPressure!);
      },
      onError: (error) {
        debugPrint('Pressure sensor error: $error');
        _controller.addError(error); // Propagate error to listeners
      },
    );
  }

  /// Stop listening to pressure sensor
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Calculate approximate altitude from pressure
  /// Uses standard atmosphere model
  double? calculateAltitude(double? seaLevelPressure) {
    if (_currentPressure == null || seaLevelPressure == null) return null;

    // Standard atmosphere formula
    // h = 44330 * (1 - (P/P0)^(1/5.255))
    return (44330 * (1 - dart_math.pow(_currentPressure! / seaLevelPressure, 1 / 5.255))).toDouble();
  }

  /// Cleanup
  void dispose() {
    stopListening();
    _controller.close();
  }
}
