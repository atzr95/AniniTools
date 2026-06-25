import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/sensors/magnetometer_service.dart';
import '../services/sensors/accelerometer_service.dart';
import '../services/sensors/location_service.dart';

/// CompassViewModel - manages compass state and sensor fusion
/// Fuses magnetometer + accelerometer for tilt-compensated heading
/// Provides GPS coordinates and altitude
class CompassViewModel extends ChangeNotifier {
  final MagnetometerService _magnetometerService = MagnetometerService();
  final AccelerometerService _accelerometerService = AccelerometerService();
  final LocationService _locationService = LocationService();

  StreamSubscription<double>? _magSubscription;
  StreamSubscription<AccelerometerData>? _accelSubscription;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _notifyTimer;
  Timer? _gpsTimeoutTimer;

  // Compass data with smoother filtering
  double _heading = 0.0; // Degrees from magnetic north (0-360)
  double _displayHeading = 0.0; // Smoothly animated heading for display

  // GPS data
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _altitude = 0.0;

  // Calibration state
  bool _isCalibrating = false;
  double _magXMin = double.infinity;
  double _magXMax = double.negativeInfinity;
  double _magYMin = double.infinity;
  double _magYMax = double.negativeInfinity;
  double _magZMin = double.infinity;
  double _magZMax = double.negativeInfinity;
  bool _hasLocationPermission = false;
  bool _isLoadingGPS = false;
  String _gpsStatus = 'Waiting for GPS...';

  // Sensor values for calibration/debugging
  double _magX = 0.0, _magY = 0.0, _magZ = 0.0;
  double _accelX = 0.0, _accelY = 0.0, _accelZ = 9.8;

  // Tilt angles for gyroscope effect
  double _pitch = 0.0;
  double _roll = 0.0;

  // Smoothing parameters
  static const double _headingAlpha = 0.15; // Increased for smoother rotation
  static const double _displayAlpha =
      0.25; // Separate smoothing for display numbers

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
      notifyListeners();
    } catch (e) {
      debugPrint('🗺️ Error requesting location permission: $e');
    }
  }

  /// Start smooth animation timer for heading display
  void _startSmoothAnimation() {
    // Update display heading smoothly at 60fps
    _notifyTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      // Smoothly interpolate display heading towards target
      final diff = _normalizeAngleDiff(_heading - _displayHeading);
      _displayHeading = _normalizeAngle(_displayHeading + diff * _displayAlpha);
      notifyListeners();
    });
  }

  /// Start sensor streams
  void _startSensorStreams() {
    // Start services
    _magnetometerService.startListening();
    _accelerometerService.startListening();

    // Always start GPS if we have permission
    if (_hasLocationPermission) {
      _isLoadingGPS = true;
      _gpsStatus = 'Acquiring GPS signal...';
      notifyListeners(); // Notify immediately to show loading state

      // Start GPS service
      _startGPSTimeout();
      _startGPSService();
    }

    // Listen to magnetometer + accelerometer for heading calculation
    _magSubscription = _magnetometerService.stream.listen((_) {
      // Get values directly from service
      _magX = _magnetometerService.x;
      _magY = _magnetometerService.y;
      _magZ = _magnetometerService.z;

      // Track min/max values during calibration
      if (_isCalibrating) {
        if (_magX < _magXMin) _magXMin = _magX;
        if (_magX > _magXMax) _magXMax = _magX;
        if (_magY < _magYMin) _magYMin = _magY;
        if (_magY > _magYMax) _magYMax = _magY;
        if (_magZ < _magZMin) _magZMin = _magZ;
        if (_magZ > _magZMax) _magZMax = _magZ;
      }

      _calculateHeading();
    });

    _accelSubscription = _accelerometerService.stream.listen((data) {
      _accelX = data.x;
      _accelY = data.y;
      _accelZ = data.z;
      _calculateHeading();
    });

    // Don't call notifyListeners() here - let the timer handle it
  }

  /// Start GPS service
  void _startGPSService() async {
    // Early check for location services
    try {
      final servicesEnabled = await _locationService.isLocationServiceEnabled();
      debugPrint('🗺️ Location services enabled: $servicesEnabled');
      if (!servicesEnabled) {
        _isLoadingGPS = false;
        _gpsStatus = 'Location services are OFF';
        _cancelGPSTimeout();
        notifyListeners();
        return;
      }
    } catch (e) {
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
      debugPrint('🗺️ Got position: $position');
      if (position != null) {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _altitude = position.altitude;
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
      _isLoadingGPS = false;
      _gpsStatus = 'GPS Error: $error';
      _cancelGPSTimeout();
      debugPrint('🗺️ Error getting initial position: $error');
      notifyListeners();
    }

    // Start location service streaming
    await _locationService.startListening();

    // Listen to location updates
    _locationSubscription = _locationService.stream.listen(
      (position) {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _altitude = position.altitude;
        _isLoadingGPS = false;
        _cancelGPSTimeout();

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
          if (!servicesEnabled) {
            _gpsStatus = 'Location services are OFF';
          } else {
            _gpsStatus = 'No GPS Signal';
          }
        } catch (_) {
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

  /// Calculate heading from magnetometer and accelerometer
  /// Uses tilt compensation for accurate readings
  void _calculateHeading() {
    // Get accelerometer values (normalized)
    final double ax = _accelX;
    final double ay = _accelY;
    final double az = _accelZ;

    // Get magnetometer values
    final double mx = _magX;
    final double my = _magY;
    final double mz = _magZ;

    // Calculate pitch and roll from accelerometer
    final double pitch = atan2(ay, sqrt(ax * ax + az * az));
    final double roll = atan2(-ax, az);

    // Store pitch and roll for gyroscope effect
    _pitch = pitch;
    _roll = roll;

    // Tilt compensation
    // Rotate magnetometer values to compensate for device tilt
    final double magXComp = mx * cos(pitch) + mz * sin(pitch);
    final double magYComp =
        mx * sin(roll) * sin(pitch) +
        my * cos(roll) -
        mz * sin(roll) * cos(pitch);

    // Calculate heading (azimuth) in radians
    // Use atan2(y, x) where standard math 0° = East, but we want 0° = North
    // So we need to rotate by 90° counter-clockwise: use atan2(-x, y)
    double newHeading = atan2(-magXComp, magYComp);

    // Convert to degrees and normalize to 0-360
    newHeading = newHeading * 180 / pi;
    if (newHeading < 0) {
      newHeading += 360;
    }

    // Apply enhanced smoothing with wrap-around handling
    _heading = _applySmoothing(_heading, newHeading, _headingAlpha);

    // Don't call notifyListeners() here - let the timer handle it for smooth 60fps updates
  }

  /// Apply low-pass filter for smooth heading changes
  double _applySmoothing(double oldValue, double newValue, double alpha) {
    final double diff = _normalizeAngleDiff(newValue - oldValue);
    final double smoothed = _normalizeAngle(oldValue + alpha * diff);
    return smoothed;
  }

  /// Normalize angle difference to -180 to 180 range
  double _normalizeAngleDiff(double diff) {
    if (diff > 180) {
      return diff - 360;
    } else if (diff < -180) {
      return diff + 360;
    }
    return diff;
  }

  /// Normalize angle to 0-360 range
  double _normalizeAngle(double angle) {
    double normalized = angle;
    while (normalized < 0) {
      normalized += 360;
    }
    while (normalized >= 360) {
      normalized -= 360;
    }
    return normalized;
  }

  /// Get cardinal direction text (N, NE, E, SE, S, SW, W, NW)
  String getDirectionText() {
    final h = _displayHeading;
    if (h >= 337.5 || h < 22.5) return 'N';
    if (h >= 22.5 && h < 67.5) return 'NE';
    if (h >= 67.5 && h < 112.5) return 'E';
    if (h >= 112.5 && h < 157.5) return 'SE';
    if (h >= 157.5 && h < 202.5) return 'S';
    if (h >= 202.5 && h < 247.5) return 'SW';
    if (h >= 247.5 && h < 292.5) return 'W';
    if (h >= 292.5 && h < 337.5) return 'NW';
    return 'N';
  }

  /// Get full direction name
  String getFullDirectionName() {
    final h = _displayHeading;
    if (h >= 337.5 || h < 22.5) return 'North';
    if (h >= 22.5 && h < 67.5) return 'Northeast';
    if (h >= 67.5 && h < 112.5) return 'East';
    if (h >= 112.5 && h < 157.5) return 'Southeast';
    if (h >= 157.5 && h < 202.5) return 'South';
    if (h >= 202.5 && h < 247.5) return 'Southwest';
    if (h >= 247.5 && h < 292.5) return 'West';
    if (h >= 292.5 && h < 337.5) return 'Northwest';
    return 'North';
  }

  /// Start compass calibration (user should rotate device in figure-8 pattern)
  void startCalibration() {
    _isCalibrating = true;
    // Reset calibration bounds
    _magXMin = double.infinity;
    _magXMax = double.negativeInfinity;
    _magYMin = double.infinity;
    _magYMax = double.negativeInfinity;
    _magZMin = double.infinity;
    _magZMax = double.negativeInfinity;
    notifyListeners();
    debugPrint('Compass calibration started - rotate device in figure-8 pattern');
  }

  /// Stop calibration and apply the calibration offsets
  void stopCalibration() {
    if (!_isCalibrating) return;

    _isCalibrating = false;

    // Calculate hard iron offsets (bias correction)
    final xOffset = (_magXMax + _magXMin) / 2;
    final yOffset = (_magYMax + _magYMin) / 2;
    final zOffset = (_magZMax + _magZMin) / 2;

    debugPrint('Calibration complete - Offsets: X=$xOffset, Y=$yOffset, Z=$zOffset');
    debugPrint('Ranges: X=${_magXMax - _magXMin}, Y=${_magYMax - _magYMin}, Z=${_magZMax - _magZMin}');

    notifyListeners();
  }

  /// Check if currently calibrating
  bool get isCalibrating => _isCalibrating;

  /// Legacy method for backward compatibility
  void calibrate() {
    startCalibration();
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _gpsTimeoutTimer?.cancel();
    _magSubscription?.cancel();
    _accelSubscription?.cancel();
    _locationSubscription?.cancel();
    _magnetometerService.stopListening();
    _accelerometerService.stopListening();
    _locationService.stopListening();
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
