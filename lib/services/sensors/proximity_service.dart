import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

/// Service for monitoring proximity sensor
/// Singleton pattern ensures only one instance exists
class ProximityService {
  static final ProximityService _instance = ProximityService._internal();
  factory ProximityService() => _instance;
  ProximityService._internal();

  StreamSubscription? _subscription;
  // Controller owns the platform subscription — see AccelerometerService.
  late final _controller = StreamController<bool>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );

  Stream<bool> get stream => _controller.stream;

  void _start() {
    try {
      _subscription = ProximitySensor.events.listen(
        (event) {
          // ProximitySensor returns distance, convert to near/far
          _controller.add(event > 0);
        },
        onError: (error) {
          debugPrint('Proximity sensor error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error starting proximity sensor: $e');
    }
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
