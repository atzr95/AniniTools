import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Magnetometer service - provides magnetic field data
/// Used for compass heading calculation
class MagnetometerService {
  static final MagnetometerService _instance = MagnetometerService._internal();
  factory MagnetometerService() => _instance;
  MagnetometerService._internal();

  StreamSubscription<MagnetometerEvent>? _subscription;
  StreamController<double> _controller = StreamController<double>.broadcast();
  Timer? _throttleTimer;
  bool _canUpdate = true;
  static const _throttleDuration = Duration(milliseconds: 100); // 10 updates/sec

  /// Stream of magnetometer field magnitude (µT)
  Stream<double> get stream {
    // Recreate controller if it was closed
    if (_controller.isClosed) {
      _controller = StreamController<double>.broadcast();
    }
    return _controller.stream;
  }

  /// Current magnetic field values (µT - microtesla)
  double _x = 0.0;
  double _y = 0.0;
  double _z = 0.0;

  double get x => _x;
  double get y => _y;
  double get z => _z;

  /// Start listening to magnetometer data
  void startListening() {
    // Recreate controller if it was closed
    if (_controller.isClosed) {
      _controller = StreamController<double>.broadcast();
    }

    // Stop any existing subscription first
    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    // Reset throttle state
    _canUpdate = true;
    _throttleTimer?.cancel();
    _throttleTimer = null;

    _subscription = magnetometerEventStream().listen(
      (MagnetometerEvent event) {
        _x = event.x;
        _y = event.y;
        _z = event.z;

        // Throttle updates to reduce CPU usage
        if (_canUpdate) {
          final magnitude = math.sqrt(_x * _x + _y * _y + _z * _z);
          _controller.add(magnitude);

          _canUpdate = false;
          _throttleTimer?.cancel();
          _throttleTimer = Timer(_throttleDuration, () {
            _canUpdate = true;
          });
        }
      },
      onError: (error) {
        debugPrint('Magnetometer error: $error');
      },
    );
  }

  /// Stop listening to magnetometer data
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
  }

  /// Dispose resources
  void dispose() {
    stopListening();
    _controller.close();
  }
}
