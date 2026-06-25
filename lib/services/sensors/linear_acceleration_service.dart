import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Linear Acceleration service - provides acceleration data WITHOUT gravity
/// Used for measuring actual movement/vehicle acceleration
class LinearAccelerationService {
  static final LinearAccelerationService _instance = LinearAccelerationService._internal();
  factory LinearAccelerationService() => _instance;
  LinearAccelerationService._internal();

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  StreamController<LinearAccelerationData> _controller = StreamController<LinearAccelerationData>.broadcast();
  Timer? _throttleTimer;
  bool _canUpdate = true;
  static const _throttleDuration = Duration(milliseconds: 50); // 20 updates/sec for smoother tracking

  /// Stream of linear acceleration data (gravity removed)
  Stream<LinearAccelerationData> get stream {
    // Recreate controller if it was closed
    if (_controller.isClosed) {
      _controller = StreamController<LinearAccelerationData>.broadcast();
    }
    return _controller.stream;
  }

  /// Current linear acceleration values (m/s²) - gravity removed
  double _x = 0.0;
  double _y = 0.0;
  double _z = 0.0;

  /// Start listening to linear acceleration data
  void startListening() {
    // Recreate controller if it was closed
    if (_controller.isClosed) {
      _controller = StreamController<LinearAccelerationData>.broadcast();
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

    // Use userAccelerometerEventStream which has gravity removed
    _subscription = userAccelerometerEventStream().listen(
      (UserAccelerometerEvent event) {
        _x = event.x;
        _y = event.y;
        _z = event.z;

        // Throttle updates to reduce CPU usage
        if (_canUpdate) {
          final magnitude = sqrt(_x * _x + _y * _y + _z * _z);

          _controller.add(LinearAccelerationData(
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
        // Error handling
      },
    );
  }

  /// Stop listening to linear acceleration data
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

/// Linear acceleration data class
class LinearAccelerationData {
  final double x; // m/s² (lateral - left/right)
  final double y; // m/s² (forward/backward)
  final double z; // m/s² (vertical - up/down)
  final double magnitude; // Combined linear acceleration magnitude

  LinearAccelerationData({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
  });
}
