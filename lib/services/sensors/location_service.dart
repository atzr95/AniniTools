import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Location service - provides GPS coordinates and altitude
/// Used for compass coordinates display and altitude calculation
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _subscription;
  final StreamController<Position> _controller = StreamController<Position>.broadcast();

  /// Stream of position updates
  Stream<Position> get stream => _controller.stream;

  /// Current position
  Position? _currentPosition;

  double get latitude => _currentPosition?.latitude ?? 0.0;
  double get longitude => _currentPosition?.longitude ?? 0.0;
  double get altitude => _currentPosition?.altitude ?? 0.0;
  double get accuracy => _currentPosition?.accuracy ?? 0.0;
  double get speed => _currentPosition?.speed ?? 0.0;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('📍 isLocationServiceEnabled: $enabled');
    return enabled;
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current position once
  Future<Position?> getCurrentPosition() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return null;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        return null;
      }

      // Get position
      _currentPosition = await Geolocator
          .getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10, // Update every 10 meters
            ),
          )
          .timeout(const Duration(seconds: 10));

      return _currentPosition;
    } catch (e) {
      debugPrint('Error getting position: $e');
      return null;
    }
  }

  /// Start listening to position updates
  Future<void> startListening() async {
    // Stop any existing subscription first
    stopListening();

    // Check if location service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled');
      return;
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permission permanently denied');
      return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _subscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _currentPosition = position;
        _controller.add(position);
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  /// Stop listening to position updates
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Dispose resources
  void dispose() {
    stopListening();
    _controller.close();
  }

  /// Open system settings helpers
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Error opening app settings: $e');
      return false;
    }
  }

  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('Error opening location settings: $e');
      return false;
    }
  }
}
