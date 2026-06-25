import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Service for calculating device orientation (pitch, roll, azimuth)
/// Uses accelerometer and magnetometer fusion
/// Singleton pattern ensures only one instance exists
class OrientationService {
  static final OrientationService _instance = OrientationService._internal();
  factory OrientationService() => _instance;
  OrientationService._internal();

  StreamSubscription? _accelSubscription;
  StreamSubscription? _magnetSubscription;
  StreamController<OrientationData> _controller = StreamController<OrientationData>.broadcast();
  Timer? _throttleTimer;
  bool _canUpdate = true;
  static const _throttleDuration = Duration(milliseconds: 100); // 10 updates/sec

  Stream<OrientationData> get stream {
    // Recreate controller if it was closed
    if (_controller.isClosed) {
      _controller = StreamController<OrientationData>.broadcast();
    }
    return _controller.stream;
  }
  OrientationData? _currentData;

  double _accelX = 0, _accelY = 0, _accelZ = 9.8;
  double _magX = 0, _magY = 0, _magZ = 0;

  /// Start listening to accelerometer and magnetometer for orientation
  Future<void> startListening() async {
    // Recreate controller if it was closed
    if (_controller.isClosed) {
      _controller = StreamController<OrientationData>.broadcast();
    }

    // Stop any existing subscriptions first
    if (_accelSubscription != null) {
      _accelSubscription!.cancel();
      _accelSubscription = null;
    }
    if (_magnetSubscription != null) {
      _magnetSubscription!.cancel();
      _magnetSubscription = null;
    }

    // Reset throttle state
    _canUpdate = true;
    _throttleTimer?.cancel();
    _throttleTimer = null;

    // Listen to accelerometer for tilt
    _accelSubscription = accelerometerEventStream().listen(
      (event) {
        _accelX = event.x;
        _accelY = event.y;
        _accelZ = event.z;
        _calculateOrientation();
      },
      onError: (error) {
        debugPrint('Accelerometer error: $error');
      },
    );

    // Listen to magnetometer for azimuth
    _magnetSubscription = magnetometerEventStream().listen(
      (event) {
        _magX = event.x;
        _magY = event.y;
        _magZ = event.z;
        _calculateOrientation();
      },
      onError: (error) {
        debugPrint('Magnetometer error: $error');
      },
    );
  }

  /// Calculate orientation (pitch, roll, azimuth) from sensor data
  void _calculateOrientation() {
    // Calculate pitch and roll from accelerometer (in radians)
    final pitch = math.atan2(_accelY, math.sqrt(_accelX * _accelX + _accelZ * _accelZ));
    final roll = math.atan2(-_accelX, _accelZ);

    // Calculate azimuth (heading) with tilt compensation
    final magXComp = _magX * math.cos(pitch) + _magZ * math.sin(pitch);
    final magYComp = _magX * math.sin(roll) * math.sin(pitch) +
        _magY * math.cos(roll) -
        _magZ * math.sin(roll) * math.cos(pitch);

    double azimuth = math.atan2(-magXComp, magYComp);

    // Convert azimuth to degrees
    var azimuthDeg = azimuth * 180 / math.pi;

    // Normalize azimuth to 0-360
    if (azimuthDeg < 0) {
      azimuthDeg += 360;
    }

    _currentData = OrientationData(
      pitch: pitch,  // Keep in radians for spirit level
      roll: roll,    // Keep in radians for spirit level
      azimuth: azimuthDeg,
    );

    // Throttle updates to reduce CPU usage
    if (_canUpdate) {
      _controller.add(_currentData!);

      _canUpdate = false;
      _throttleTimer?.cancel();
      _throttleTimer = Timer(_throttleDuration, () {
        _canUpdate = true;
      });
    }
  }

  /// Stop listening
  void stopListening() {
    _accelSubscription?.cancel();
    _magnetSubscription?.cancel();
    _accelSubscription = null;
    _magnetSubscription = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
  }

  /// Cleanup
  void dispose() {
    stopListening();
    _controller.close();
  }
}

/// Orientation data class
class OrientationData {
  final double pitch; // Radians for spirit level
  final double roll; // Radians for spirit level
  final double azimuth; // Degrees (0 to 360), magnetic heading

  OrientationData({
    required this.pitch,
    required this.roll,
    required this.azimuth,
  });
}
