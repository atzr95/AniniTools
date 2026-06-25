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
  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get stream => _controller.stream;
  bool? _isNear;

  /// Start listening to proximity sensor
  Future<void> startListening() async {
    // Stop any existing subscription first
    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    try {
      _subscription = ProximitySensor.events.listen(
        (event) {
          _isNear = event > 0; // ProximitySensor returns distance, convert to near/far
          _controller.add(_isNear!);
        },
        onError: (error) {
          debugPrint('Proximity sensor error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error starting proximity sensor: $e');
    }
  }

  /// Stop listening to proximity sensor
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Cleanup
  void dispose() {
    stopListening();
    _controller.close();
  }
}
