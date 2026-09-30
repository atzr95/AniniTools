import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/sensors/orientation_service.dart';
import '../services/sensors/location_service.dart';

/// CompassViewModel - manages compass state
/// Consumes OrientationService (the single source of tilt-compensated heading)
/// and smooths it at ~30fps for display. Provides GPS coordinates and altitude.
class CompassViewModel extends ChangeNotifier {
  final OrientationService _orientationService = OrientationService();
  final LocationService _locationService = LocationService();

  StreamSubscription<OrientationData>? _orientationSubscription;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _notifyTimer;
  Timer? _gpsTimeoutTimer;
  bool _sensorDataChanged = false;

  // Compass data with smoother filtering
  double _heading = 0.0; // Degrees from magnetic north (0-360)
  double _displayHeading = 0.0; // Smoothly animated heading for display

  // GPS data
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _altitude = 0.0;

  bool _hasLocationPermission = false;
  bool _isLoadingGPS = false;
  String _gpsStatus = 'Waiting for GPS...';

  // Tilt angles for gyroscope effect
  double _pitch = 0.0;
  double _roll = 0.0;

  // Set in dispose(). The async start paths below await a permission prompt or
  // a GPS fix before subscribing; without this they would subscribe (and start
  // the display timer) after dispose() already ran, pinning the orientation
  // sensors / position stream on with a listener no live object can cancel.
  bool _disposed = false;

  // Smoothing parameters
  static const double _headingAlpha = 0.15; // Increased for smoother rotation
  static const double _displayAlpha =
      0.25; // Separate smoothing for display numbers

  static const _directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  static const _directionNames = [
    'North',
    'Northeast',
    'East',
    'Southeast',
    'South',
    'Southwest',
    'West',
    'Northwest',
  ];

  // Getters
  double get heading => _displayHeading;
  double get latitude => _latitude;
  double get longitude => _longitude;
  double get altitude => _altitude;
  bool get hasLocationPermission => _hasLocationPermission;
  bool get isLoadingGPS => _isLoadingGPS;
  String get gpsStatus => _gpsStatus;
  double get pitch => _pitch;
  double get roll => _roll;

  /// Initialize compass - start sensor streams
  Future<void> initialize() async {
    await _requestLocationPermission();
    if (_disposed) return;
    _startSensorStreams();
    _startSmoothAnimation();
  }

  /// Request location permission
  Future<void> _requestLocationPermission() async {
    try {
      final permission = await _locationService.checkPermission();
      debugPrint('🗺️ Current permission: $permission');
      if (permission == LocationPermission.denied) {
        final result = await _locationService.requestPermission();
        debugPrint('🗺️ Permission request result: $result');
        _hasLocationPermission =
            result == LocationPermission.whileInUse ||
            result == LocationPermission.always;
      } else {
        _hasLocationPermission =
            permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always;
      }
      debugPrint('🗺️ Has location permission: $_hasLocationPermission');
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('🗺️ Error requesting location permission: $e');
    }
  }

  /// Start smooth animation timer for heading display
  void _startSmoothAnimation() {
    // Update only while the heading changes; idle sensors need no rebuilds.
    _notifyTimer?.cancel();
    _notifyTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      // Smoothly interpolate display heading towards target
      final nextHeading = _applySmoothing(
        _displayHeading,
        _heading,
        _displayAlpha,
      );
      final headingChanged =
          normalizeAngleDiff(nextHeading - _displayHeading).abs() > 0.05;
      _displayHeading = nextHeading;
      if (headingChanged || _sensorDataChanged) {
        _sensorDataChanged = false;
        notifyListeners();
      }
    });
  }

  /// Start sensor streams
  void _startSensorStreams() {
    // Always start GPS if we have permission
    if (_hasLocationPermission) {
      _isLoadingGPS = true;
      _gpsStatus = 'Acquiring GPS signal...';
      notifyListeners(); // Notify immediately to show loading state

      // Start GPS service
      _startGPSTimeout();
      _startGPSService();
    }

    // Orientation service owns the tilt-compensated heading math. Subscribing
    // starts it; the permission-retry button can call initialize() again, so
    // drop any previous subscription rather than pinning the sensor on with a
    // listener nothing will ever cancel.
    _orientationSubscription?.cancel();
    _orientationSubscription = _orientationService.stream.listen((data) {
      if (data.pitch != _pitch ||
          data.roll != _roll ||
          normalizeAngleDiff(data.azimuth - _heading).abs() > 0.05) {
        _sensorDataChanged = true;
      }
      _pitch = data.pitch;
      _roll = data.roll;
      // Apply enhanced smoothing with wrap-around handling
      _heading = _applySmoothing(_heading, data.azimuth, _headingAlpha);
      // Don't call notifyListeners() here - the display timer handles it
    });
  }

  /// Start GPS service
  void _startGPSService() async {
    // Early check for location services
    try {
      final servicesEnabled = await _locationService.isLocationServiceEnabled();
      if (_disposed) return;
      debugPrint('🗺️ Location services enabled: $servicesEnabled');
      if (!servicesEnabled) {
        _isLoadingGPS = false;
        _gpsStatus = 'Location services are OFF';
        _cancelGPSTimeout();
        notifyListeners();
        return;
      }
    } catch (e) {
      if (_disposed) return;
      debugPrint('🗺️ Error checking location services: $e');
      _isLoadingGPS = false;
      _gpsStatus = 'GPS Error: $e';
      _cancelGPSTimeout();
      notifyListeners();
      return;
    }

    // Try to get initial position first
    try {
      debugPrint('🗺️ Requesting initial GPS position...');
      final position = await _locationService.getCurrentPosition();
      if (_disposed) return;
      debugPrint('🗺️ Got position: $position');
      if (position != null) {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _altitude = position.altitude;
        _sensorDataChanged = true;
        _isLoadingGPS = false;
        _gpsStatus = 'GPS Ready';
        _cancelGPSTimeout();
        debugPrint(
          '🗺️ GPS Ready: ${position.latitude}, ${position.longitude}',
        );
        notifyListeners();
      } else {
        _isLoadingGPS = false;
        _gpsStatus = 'No GPS Signal';
        _cancelGPSTimeout();
        debugPrint('🗺️ No GPS Signal - position is null');
        notifyListeners();
      }
    } catch (error) {
      if (_disposed) return;
      _isLoadingGPS = false;
      _gpsStatus = 'GPS Error: $error';
      _cancelGPSTimeout();
      debugPrint('🗺️ Error getting initial position: $error');
      notifyListeners();
    }

    // Subscribing starts the location stream. initialize() can run again from
    // the permission-retry button, so drop any previous subscription first.
    if (_disposed) return;
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.stream.listen(
      (position) {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _altitude = position.altitude;
        _isLoadingGPS = false;
        _cancelGPSTimeout();
        _sensorDataChanged = true;

        // Update GPS status based on accuracy
        if (position.accuracy < 10) {
          _gpsStatus = 'Excellent GPS';
        } else if (position.accuracy < 20) {
          _gpsStatus = 'Good GPS';
        } else if (position.accuracy < 50) {
          _gpsStatus = 'Fair GPS';
        } else {
          _gpsStatus = 'Poor GPS';
        }

        // No need to call notifyListeners() here as timer handles it
      },
      onError: (error) {
        _isLoadingGPS = false;
        _gpsStatus = 'GPS Error: $error';
        _cancelGPSTimeout();
        debugPrint('GPS stream error: $error');
      },
    );
  }

  /// Start a timeout so we don't show \"Acquiring...\" indefinitely
  void _startGPSTimeout() {
    _gpsTimeoutTimer?.cancel();
    _gpsTimeoutTimer = Timer(const Duration(seconds: 12), () async {
      if (_isLoadingGPS) {
        // Re-check if services are enabled to give a clearer message
        try {
          final servicesEnabled = await _locationService
              .isLocationServiceEnabled();
          if (_disposed) return;
          if (!servicesEnabled) {
            _gpsStatus = 'Location services are OFF';
          } else {
            _gpsStatus = 'No GPS Signal';
          }
        } catch (_) {
          if (_disposed) return;
          _gpsStatus = 'No GPS Signal';
        }
        _isLoadingGPS = false;
        notifyListeners();
      }
    });
  }

  void _cancelGPSTimeout() {
    _gpsTimeoutTimer?.cancel();
    _gpsTimeoutTimer = null;
  }

  /// Apply low-pass filter for smooth heading changes
  double _applySmoothing(double oldValue, double newValue, double alpha) {
    return normalizeAngle(
      oldValue + alpha * normalizeAngleDiff(newValue - oldValue),
    );
  }

  /// Normalize angle difference to -180 to 180 range.
  /// Already-in-range diffs pass through untouched so that exactly ±180 keeps
  /// its sign — the modulo alone would collapse +180 to -180 and flip the
  /// smoothing filter's direction as the target crosses the antipode.
  static double normalizeAngleDiff(double diff) =>
      diff.abs() <= 180 ? diff : (diff + 540) % 360 - 180;

  /// Normalize angle to 0-360 range (Dart's % is already non-negative)
  static double normalizeAngle(double angle) => angle % 360;

  /// Index of the 45° compass bucket a heading falls into (0 = N, 1 = NE, ...)
  static int directionIndex(double heading) => ((heading + 22.5) ~/ 45) % 8;

  /// Get cardinal direction text (N, NE, E, SE, S, SW, W, NW)
  String getDirectionText() => _directions[directionIndex(_displayHeading)];

  /// Get full direction name
  String getFullDirectionName() =>
      _directionNames[directionIndex(_displayHeading)];

  /// Start compass calibration (user should rotate device in figure-8 pattern)
  void startCalibration() {
    _orientationService.startCalibration();
    notifyListeners();
  }

  /// Stop calibration and apply the calibration offsets
  void stopCalibration() {
    _orientationService.stopCalibration();
    notifyListeners();
  }

  /// Check if currently calibrating
  bool get isCalibrating => _orientationService.isCalibrating;

  @override
  void dispose() {
    _disposed = true;
    _notifyTimer?.cancel();
    _gpsTimeoutTimer?.cancel();
    // Drop an abandoned figure-8 explicitly: the service is a singleton and the
    // next screen mounts before this one unmounts, so its listener count may
    // never hit zero and its own reset never fires. Completed calibrations keep
    // their offsets — this only clears an in-progress one.
    _orientationService.cancelCalibration();
    // Cancelling the orientation subscription IS stopping it — the service
    // drops its platform subscriptions when its last listener leaves.
    _orientationSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// Expose helpers to open system settings
  Future<bool> openAppSettings() {
    return _locationService.openAppSettings();
  }

  Future<bool> openLocationSettings() {
    return _locationService.openLocationSettings();
  }
}
