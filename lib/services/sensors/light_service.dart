import 'dart:async';

/// Service for monitoring ambient light sensor
/// Singleton pattern ensures only one instance exists
///
/// NOTE: Light sensor functionality is currently disabled due to package compatibility issues
/// The 'light' package is incompatible with Flutter 3.27+ and Android Gradle Plugin 8.x
/// Future implementation may use platform channels or wait for package updates
class LightService {
  static final LightService _instance = LightService._internal();
  factory LightService() => _instance;
  LightService._internal();

  final _controller = StreamController<double>.broadcast();

  Stream<double> get stream => _controller.stream;
  final double _currentLux = 0.0;

  /// Check if light sensor is available
  /// Currently always returns false due to disabled functionality
  Future<bool> isAvailable() async {
    return false; // Disabled - package incompatibility
  }

  /// Start listening to light sensor
  /// Currently does nothing due to disabled functionality
  Future<void> startListening() async {
    // Disabled - package incompatibility
    // Future implementation: use platform channels or updated package
  }

  /// Stop listening to light sensor
  void stopListening() {
    // No-op
  }

  /// Get current light level
  double? get currentLux => _currentLux;

  /// Cleanup
  void dispose() {
    _controller.close();
  }
}
