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
  Future<LocationPermission>? _permissionRequest;
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
  Future<LocationPermission> requestPermission() => _permissionRequest ??=
      _requestPermission().whenComplete(() => _permissionRequest = null);

  Future<LocationPermission> _requestPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.denied
        ? Geolocator.requestPermission()
        : permission;
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
        return null;
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
        _controller.addError(StateError('Location services are off'));
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _controller.addError(StateError('Location permission denied'));
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _controller.addError(StateError('Location permission denied'));
        return;
      }

      // The last listener may have cancelled during the awaits above; _stop()
      // would then have already run as a no-op, so don't open the GPS stream
      // behind it. A 1->0->1 flip in that same window starts a second _start()
      // too: whichever body gets here first owns _subscription, and the other
      // bails rather than overwriting a handle _stop() could never cancel.
      if (!_controller.hasListener || _subscription != null) return;

      // A movement filter suppresses the final speed-zero fix when a phone stops.
      final LocationSettings locationSettings =
          defaultTargetPlatform == TargetPlatform.android
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              intervalDuration: const Duration(seconds: 1),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
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
              _controller.addError(error);
            },
          );
    } catch (e) {
      debugPrint('Error starting location updates: $e');
      _controller.addError(e);
    }
  }

  /// Restart the shared platform stream for a retry. While another screen
  /// still listens, a new listener does not fire onListen, so a stream that
  /// failed to start (services off, permission denied) would stay dead.
  void restart() {
    _stop();
    if (_controller.hasListener) _start();
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
