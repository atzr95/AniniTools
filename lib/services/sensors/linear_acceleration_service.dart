import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'vector3_reading.dart';

/// Linear Acceleration service - provides acceleration data WITHOUT gravity
/// Used for measuring actual movement/vehicle acceleration
class LinearAccelerationService {
  static final LinearAccelerationService _instance =
      LinearAccelerationService._internal();
  factory LinearAccelerationService() => _instance;
  LinearAccelerationService._internal();

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  // Controller owns the platform subscription — see AccelerometerService.
  late final _controller = StreamController<Vector3Reading>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );
  // 5 Hz — the pre-refactor effective rate. The old 50 ms Timer throttle read
  // as 20 Hz but never bound: the stream default was already 200 ms.
  static const _samplingPeriod = SensorInterval.normalInterval; // 200 ms

  /// Stream of linear acceleration data (gravity removed)
  Stream<Vector3Reading> get stream => _controller.stream;

  void _start() {
    // Use userAccelerometerEventStream which has gravity removed
    _subscription =
        userAccelerometerEventStream(samplingPeriod: _samplingPeriod).listen(
          (UserAccelerometerEvent event) {
            _controller.add(Vector3Reading(event.x, event.y, event.z));
          },
          onError: (error) {
            // Error handling
          },
        );
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
