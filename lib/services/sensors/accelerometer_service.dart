import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Accelerometer service - provides acceleration data
/// Used for compass tilt compensation and spirit level
class AccelerometerService {
  static final AccelerometerService _instance = AccelerometerService._internal();
  factory AccelerometerService() => _instance;
  AccelerometerService._internal();

  StreamSubscription<AccelerometerEvent>? _subscription;
  StreamController<AccelerometerData> _controller = StreamController<AccelerometerData>.broadcast();
  Timer? _throttleTimer;
  bool _canUpdate = true;
  static const _throttleDuration = Duration(milliseconds: 100); // 10 updates/sec

  /// Stream of accelerometer data with magnitude
  Stream<AccelerometerData> get stream {
    // Recreate controller if it was closed
    if (_controller.isClosed) {
      _controller = StreamController<AccelerometerData>.broadcast();
    }
    return _controller.stream;
  }

  /// Current acceleration values (m/s²)
  double _x = 0.0;
  double _y = 0.0;
  double _z = 9.8; // Default gravity

  /// Start listening to accelerometer data
  void startListening() {
    // Recreate controller if it was closed
    if (_controller.isClosed) {
      _controller = StreamController<AccelerometerData>.broadcast();
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

    _subscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        _x = event.x;
        _y = event.y;
        _z = event.z;

        // Throttle updates to reduce CPU usage
        if (_canUpdate) {
          final magnitude = sqrt(_x * _x + _y * _y + _z * _z);

          _controller.add(AccelerometerData(
            x: _x,
            y: _y,
            z: _z,
            magnitude: magnitude,
          ));

          _canUpdate = false;
          _throttleTimer?.cancel();
          _throttleTimer = Timer(_throttleDuration, () {
            _canUpdate = true;
          });
        }
      },
      onError: (error) {
        debugPrint('Accelerometer error: $error');
      },
    );
  }

  /// Stop listening to accelerometer data
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

/// Accelerometer data class
class AccelerometerData {
  final double x; // m/s²
  final double y; // m/s²
  final double z; // m/s²
  final double magnitude; // Combined acceleration magnitude

  AccelerometerData({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
  });
}
