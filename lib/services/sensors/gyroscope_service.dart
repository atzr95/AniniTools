import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Service for monitoring gyroscope (angular velocity)
/// Singleton pattern ensures only one instance exists
class GyroscopeService {
  static final GyroscopeService _instance = GyroscopeService._internal();
  factory GyroscopeService() => _instance;
  GyroscopeService._internal();

  StreamSubscription? _subscription;
  StreamController<GyroscopeData> _controller = StreamController<GyroscopeData>.broadcast();
  Timer? _throttleTimer;
  bool _canUpdate = true;
  static const _throttleDuration = Duration(milliseconds: 100); // 10 updates/sec

  Stream<GyroscopeData> get stream {
    // Recreate controller if it was closed
    if (_controller.isClosed) {
      _controller = StreamController<GyroscopeData>.broadcast();
    }
    return _controller.stream;
  }
  GyroscopeData? _currentData;

  /// Start listening to gyroscope
  Future<void> startListening() async {
    // Recreate controller if it was closed
    if (_controller.isClosed) {
      _controller = StreamController<GyroscopeData>.broadcast();
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

    _subscription = gyroscopeEventStream().listen(
      (event) {
        // Calculate magnitude of angular velocity vector
        final magnitude = math.sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );

        _currentData = GyroscopeData(
          x: event.x,
          y: event.y,
          z: event.z,
          magnitude: magnitude,
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
      },
      onError: (error) {
        debugPrint('Gyroscope error: $error');
      },
    );
  }

  /// Stop listening to gyroscope
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _throttleTimer?.cancel();
    _throttleTimer = null;
  }

  /// Cleanup
  void dispose() {
    stopListening();
    _controller.close();
  }
}

/// Gyroscope data class
class GyroscopeData {
  final double x; // rad/s
  final double y; // rad/s
  final double z; // rad/s
  final double magnitude; // Combined angular velocity magnitude

  GyroscopeData({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
  });
}
