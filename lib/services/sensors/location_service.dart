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
  // Controller owns the platform subscription — see AccelerometerService.
  late final StreamController<Position> _controller =
      StreamController<Position>.broadcast(onListen: _start, onCancel: _stop);

  /// Stream of position updates
  Stream<Position> get stream => _controller.stream;

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
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error getting position: $e');
      return null;
    }
  }

  /// Start listening to position updates. Fired by onListen, so nothing is
  /// awaiting it — it must swallow its own errors.
  Future<void> _start() async {
    try {
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

      // The last listener may have cancelled during the awaits above; _stop()
      // would then have already run as a no-op, so don't open the GPS stream
      // behind it. A 1->0->1 flip in that same window starts a second _start()
      // too: whichever body gets here first owns _subscription, and the other
      // bails rather than overwriting a handle _stop() could never cancel.
      if (!_controller.hasListener || _subscription != null) return;

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      );

      _subscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              _controller.add(position);
            },
            onError: (error) {
              debugPrint('Location stream error: $error');
            },
          );
    } catch (e) {
      debugPrint('Error starting location updates: $e');
    }
  }

  /// Stop listening to position updates
  void _stop() {
    _subscription?.cancel();
    _subscription = null;
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
