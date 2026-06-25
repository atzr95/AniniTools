import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// Import all sensor services
import '../services/sensors/battery_service.dart';
import '../services/sensors/light_service.dart';
import '../services/sensors/magnetometer_service.dart';
import '../services/sensors/gyroscope_service.dart';
import '../services/sensors/proximity_service.dart';
import '../services/sensors/pressure_service.dart';
import '../services/sensors/sound_service.dart';
import '../services/sensors/orientation_service.dart';
import '../services/sensors/accelerometer_service.dart';
import '../services/sensors/linear_acceleration_service.dart';
import '../services/sensors/location_service.dart';

/// ViewModel for sensor screen
/// Manages all sensor data streams and card expansion states
class SensorViewModel extends ChangeNotifier {
  // Services
  final BatteryService _batteryService = BatteryService();
  final LightService _lightService = LightService();
  final MagnetometerService _magnetometerService = MagnetometerService();
  final GyroscopeService _gyroscopeService = GyroscopeService();
  final ProximityService _proximityService = ProximityService();
  final PressureService _pressureService = PressureService();
  final SoundService _soundService = SoundService();
  final OrientationService _orientationService = OrientationService();
  final AccelerometerService _accelerometerService = AccelerometerService();
  final LinearAccelerationService _linearAccelerationService =
      LinearAccelerationService();
  final LocationService _locationService = LocationService();

  // Subscriptions
  StreamSubscription? _batterySubscription;
  StreamSubscription? _lightSubscription;
  StreamSubscription? _magnetometerSubscription;
  StreamSubscription? _gyroscopeSubscription;
  StreamSubscription? _proximitySubscription;
  StreamSubscription? _pressureSubscription;
  StreamSubscription? _decibelSubscription;
  StreamSubscription? _pitchSubscription;
  StreamSubscription? _orientationSubscription;
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _linearAccelerationSubscription;
  StreamSubscription? _locationSubscription;

  // Battery data
  int _batteryLevel = 0;
  String _batteryStatus = 'Unknown';
  bool _isCharging = false;

  // Light sensor
  double _lightLevel = 0.0;

  // Magnetometer
  double _magneticField = 0.0;

  // Gyroscope
  double _gyroX = 0.0, _gyroY = 0.0, _gyroZ = 0.0;
  double _gyroMagnitude = 0.0;

  // Proximity
  bool _isNear = false;

  // Pressure
  double _pressure = 0.0;

  // Sound
  double _decibel = 0.0;
  double _pitchFrequency = 0.0;
  String _pitchNote = '--';

  // Orientation
  double _pitch = 0.0, _roll = 0.0, _azimuth = 0.0;

  // Accelerometer (includes gravity)
  double _accelX = 0.0, _accelY = 0.0, _accelZ = 0.0;
  double _accelMagnitude = 0.0;

  // Linear Acceleration (gravity removed - for movement detection)
  double _linearAccelX = 0.0, _linearAccelY = 0.0, _linearAccelZ = 0.0;
  double _linearAccelMagnitude = 0.0;

  // GPS/Location
  double _latitude = 0.0, _longitude = 0.0, _altitude = 0.0;
  double _gpsSpeed = 0.0; // m/s from GPS
  double _gpsAccuracy = 0.0;
  bool _hasLocationPermission = false;
  bool _isLoadingGPS = false;
  String _gpsStatus = 'Waiting...';

  // Sound permission state — distinguishes "hardware missing" from "user denied mic"
  bool _soundPermissionDenied = false;
  bool get soundPermissionDenied => _soundPermissionDenied;

  // Card expansion states
  final Map<String, bool> _expandedCards = {};

  // Sensor availability tracking
  final Map<String, bool> _sensorAvailability = {
    'battery': true, // Battery always available
    'light': false,
    'magnetic': false,
    'gyroscope': false,
    'proximity': false,
    'pressure': false,
    'sound': false,
    'orientation': false,
    'accelerometer': false,
    'gps': false,
  };

  // Graph data buffers (for charts)
  final Map<String, List<double>> _graphData = {
    'light': [],
    'magnetic': [],
    'decibel': [],
    'pitch': [],
    'gyroscope': [],
    'accelerometer': [],
  };
  static const int _maxGraphPoints = 100;

  // UI update throttling
  Timer? _uiUpdateTimer;
  bool _hasDataToUpdate = false;
  static const _uiUpdateInterval = Duration(
    milliseconds: 100,
  ); // 10 FPS max - reduced for better performance

  // Getters for battery
  int get batteryLevel => _batteryLevel;
  String get batteryStatus => _batteryStatus;
  bool get isCharging => _isCharging;

  // Getters for light
  double get lightLevel => _lightLevel;
  List<double> get lightGraphData => _graphData['light']!;

  // Getters for magnetic
  double get magneticField => _magneticField;
  List<double> get magneticGraphData => _graphData['magnetic']!;

  // Getters for gyroscope
  double get gyroX => _gyroX;
  double get gyroY => _gyroY;
  double get gyroZ => _gyroZ;
  double get gyroMagnitude => _gyroMagnitude;
  List<double> get gyroscopeGraphData => _graphData['gyroscope']!;

  // Getters for proximity
  bool get isNear => _isNear;

  // Getters for pressure
  double get pressure => _pressure;

  // Getters for sound
  double get decibel => _decibel;
  double get pitchFrequency => _pitchFrequency;
  String get pitchNote => _pitchNote;
  List<double> get decibelGraphData => _graphData['decibel']!;
  List<double> get pitchGraphData => _graphData['pitch']!;

  // Getters for orientation
  double get pitch => _pitch;
  double get roll => _roll;
  double get azimuth => _azimuth;

  // Getters for accelerometer
  double get accelX => _accelX;
  double get accelY => _accelY;
  double get accelZ => _accelZ;
  double get accelMagnitude => _accelMagnitude;
  List<double> get accelerometerGraphData => _graphData['accelerometer']!;

  // Getters for linear acceleration (gravity removed)
  double get linearAccelX => _linearAccelX;
  double get linearAccelY => _linearAccelY;
  double get linearAccelZ => _linearAccelZ;
  double get linearAccelMagnitude => _linearAccelMagnitude;

  // Getters for GPS
  double get latitude => _latitude;
  double get longitude => _longitude;
  double get altitude => _altitude;
  double get gpsSpeed => _gpsSpeed; // m/s
  double get gpsSpeedKmh => _gpsSpeed * 3.6; // km/h
  double get gpsAccuracy => _gpsAccuracy;
  bool get hasLocationPermission => _hasLocationPermission;
  bool get isLoadingGPS => _isLoadingGPS;
  String get gpsStatus => _gpsStatus;

  // Card expansion states
  bool isCardExpanded(String sensorName) => _expandedCards[sensorName] ?? false;

  // Sensor availability
  bool isSensorAvailable(String sensorName) =>
      _sensorAvailability[sensorName] ?? false;

  /// Initialize all available sensors
  Future<void> initialize() async {
    // Start UI update timer
    _startUIUpdateTimer();

    await _startBatterySensor();
    await _startLightSensor();
    await _startMagnetometer();
    await _startGyroscope();
    await _startProximitySensor();
    await _startPressureSensor();
    await _startOrientationSensor();
    await _startAccelerometer();
    await _startLinearAcceleration();
    await _requestLocationPermission();
    await startSoundMonitoring(); // Start sound monitoring automatically
  }

  /// Start UI update timer to throttle notifyListeners calls
  void _startUIUpdateTimer() {
    _uiUpdateTimer = Timer.periodic(_uiUpdateInterval, (_) {
      if (_hasDataToUpdate) {
        _hasDataToUpdate = false;
        notifyListeners();
      }
    });
  }

  /// Schedule a UI update (throttled)
  void _scheduleUIUpdate() {
    _hasDataToUpdate = true;
  }

  /// Battery sensor
  Future<void> _startBatterySensor() async {
    await _batteryService.startListening();
    _batterySubscription = _batteryService.stream.listen((info) {
      _batteryLevel = info.level;
      _batteryStatus = info.state;
      _isCharging = info.isCharging;
      _scheduleUIUpdate();
    });
  }

  /// Light sensor
  Future<void> _startLightSensor() async {
    final available = await _lightService.isAvailable();
    _sensorAvailability['light'] = available;
    if (available) {
      await _lightService.startListening();
      _lightSubscription = _lightService.stream.listen((lux) {
        _lightLevel = lux;
        _addGraphData('light', lux);
        _scheduleUIUpdate();
      });
    }
  }

  /// Magnetometer
  Future<void> _startMagnetometer() async {
    try {
      _magnetometerService.startListening();
      _magnetometerSubscription = _magnetometerService.stream.listen((field) {
        _magneticField = field;
        _addGraphData('magnetic', field);
        _scheduleUIUpdate();
      });
      _sensorAvailability['magnetic'] = true;
    } catch (e) {
      _sensorAvailability['magnetic'] = false;
    }
  }

  /// Gyroscope
  Future<void> _startGyroscope() async {
    try {
      await _gyroscopeService.startListening();
      _gyroscopeSubscription = _gyroscopeService.stream.listen((data) {
        _gyroX = data.x;
        _gyroY = data.y;
        _gyroZ = data.z;
        _gyroMagnitude = data.magnitude;
        _addGraphData('gyroscope', data.magnitude);
        _scheduleUIUpdate();
      });
      _sensorAvailability['gyroscope'] = true;
    } catch (e) {
      _sensorAvailability['gyroscope'] = false;
    }
  }

  /// Proximity sensor
  Future<void> _startProximitySensor() async {
    try {
      await _proximityService.startListening();
      _proximitySubscription = _proximityService.stream.listen((isNear) {
        _isNear = isNear;
        _scheduleUIUpdate();
      });
      _sensorAvailability['proximity'] = true;
    } catch (e) {
      _sensorAvailability['proximity'] = false;
    }
  }

  /// Pressure sensor
  Future<void> _startPressureSensor() async {
    try {
      await _pressureService.startListening();
      _pressureSubscription = _pressureService.stream.listen(
        (hPa) {
          _pressure = hPa;
          _sensorAvailability['pressure'] =
              true; // Mark available on first data
          _scheduleUIUpdate();
        },
        onError: (error) {
          _sensorAvailability['pressure'] = false; // Mark unavailable on error
          _scheduleUIUpdate();
        },
      );
    } catch (e) {
      _sensorAvailability['pressure'] = false;
    }
  }

  /// Orientation sensor
  Future<void> _startOrientationSensor() async {
    try {
      await _orientationService.startListening();
      _orientationSubscription = _orientationService.stream.listen((data) {
        _pitch = data.pitch;
        _roll = data.roll;
        _azimuth = data.azimuth;
        _scheduleUIUpdate();
      });
      _sensorAvailability['orientation'] = true;
    } catch (e) {
      _sensorAvailability['orientation'] = false;
    }
  }

  /// Accelerometer (includes gravity)
  Future<void> _startAccelerometer() async {
    try {
      _accelerometerService.startListening();
      _accelerometerSubscription = _accelerometerService.stream.listen((data) {
        _accelX = data.x;
        _accelY = data.y;
        _accelZ = data.z;
        _accelMagnitude = data.magnitude;
        _addGraphData('accelerometer', data.magnitude);
        _scheduleUIUpdate();
      });
      _sensorAvailability['accelerometer'] = true;
    } catch (e) {
      _sensorAvailability['accelerometer'] = false;
    }
  }

  /// Linear Acceleration (gravity removed - for movement detection)
  Future<void> _startLinearAcceleration() async {
    try {
      _linearAccelerationService.startListening();
      _linearAccelerationSubscription = _linearAccelerationService.stream
          .listen((data) {
            _linearAccelX = data.x;
            _linearAccelY = data.y;
            _linearAccelZ = data.z;
            _linearAccelMagnitude = data.magnitude;
            _scheduleUIUpdate();
          });
    } catch (e) {
      // Linear acceleration not available
    }
  }

  /// Request location permission
  Future<void> _requestLocationPermission() async {
    try {
      final permission = await _locationService.requestPermission();
      _hasLocationPermission =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (_hasLocationPermission) {
        await _startGPSService();
        _sensorAvailability['gps'] = true;
      }
    } catch (e) {
      _sensorAvailability['gps'] = false;
    }
    _scheduleUIUpdate();
  }

  /// Start GPS service
  Future<void> _startGPSService() async {
    _isLoadingGPS = true;
    _gpsStatus = 'Acquiring GPS signal...';
    _scheduleUIUpdate();

    try {
      // Check if location services are enabled
      final servicesEnabled = await _locationService.isLocationServiceEnabled();
      if (!servicesEnabled) {
        _isLoadingGPS = false;
        _gpsStatus = 'Location services OFF';
        _scheduleUIUpdate();
        return;
      }

      // Get initial position
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _altitude = position.altitude;
        _gpsSpeed = position.speed >= 0 ? position.speed : 0.0;
        _gpsAccuracy = position.accuracy;
        _isLoadingGPS = false;
        _gpsStatus = 'GPS Ready';
        _scheduleUIUpdate();
      }

      // Start listening to position updates
      await _locationService.startListening();
      _locationSubscription = _locationService.stream.listen((position) {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _altitude = position.altitude;
        _gpsSpeed = position.speed >= 0 ? position.speed : 0.0;
        _gpsAccuracy = position.accuracy;
        _isLoadingGPS = false;
        _gpsStatus = position.accuracy < 10 ? 'Excellent GPS' : 'Good GPS';
        _scheduleUIUpdate();
      });
    } catch (e) {
      _isLoadingGPS = false;
      _gpsStatus = 'GPS Error';
      _scheduleUIUpdate();
    }
  }

  /// Start sound monitoring (requires permission)
  Future<void> startSoundMonitoring() async {
    try {
      final granted = await _soundService.requestPermission();
      if (!granted) {
        _sensorAvailability['sound'] = false;
        _soundPermissionDenied = true;
        _scheduleUIUpdate();
        return;
      }

      await _soundService.startListening();

      _decibelSubscription = _soundService.decibelStream.listen((db) {
        _decibel = db;
        _addGraphData('decibel', db);
        _scheduleUIUpdate();
      });

      _pitchSubscription = _soundService.pitchStream.listen((data) {
        _pitchFrequency = data.frequency;
        _pitchNote = data.noteName;
        _addGraphData('pitch', data.frequency);
        _scheduleUIUpdate();
      });
      _sensorAvailability['sound'] = true;
      _soundPermissionDenied = false;
      _scheduleUIUpdate();
    } catch (e) {
      _sensorAvailability['sound'] = false;
      debugPrint('Sound monitoring failed to start: $e');
    }
  }

  /// Retry sound monitoring after a permission denial.
  /// Called from the UI when the user taps "Enable microphone".
  Future<void> retrySoundMonitoring() async {
    // Cancel any leftover subscriptions before retrying
    await _decibelSubscription?.cancel();
    await _pitchSubscription?.cancel();
    _decibelSubscription = null;
    _pitchSubscription = null;
    await startSoundMonitoring();
  }

  /// Stop sound monitoring
  Future<void> stopSoundMonitoring() async {
    await _soundService.stopListening();
    _decibelSubscription?.cancel();
    _pitchSubscription?.cancel();
  }

  /// Toggle card expansion state
  void toggleCard(String sensorName) {
    _expandedCards[sensorName] = !(_expandedCards[sensorName] ?? false);
    notifyListeners();
  }

  /// Add data point to graph buffer
  void _addGraphData(String sensorName, double value) {
    if (_graphData[sensorName] == null) return;

    _graphData[sensorName]!.add(value);

    // Keep buffer size limited
    if (_graphData[sensorName]!.length > _maxGraphPoints) {
      _graphData[sensorName]!.removeAt(0);
    }
  }

  /// Clear graph data for a sensor
  void clearGraphData(String sensorName) {
    _graphData[sensorName]?.clear();
    notifyListeners();
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  /// Retry GPS setup — re-requests permission and restarts the location
  /// stream. Called from the UI after the user taps "Enable Location".
  Future<void> retryLocationPermission() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await _requestLocationPermission();
  }

  @override
  void dispose() {
    // Cancel UI update timer
    _uiUpdateTimer?.cancel();

    // Cancel all subscriptions
    _batterySubscription?.cancel();
    _lightSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _proximitySubscription?.cancel();
    _pressureSubscription?.cancel();
    _decibelSubscription?.cancel();
    _pitchSubscription?.cancel();
    _orientationSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _linearAccelerationSubscription?.cancel();
    _locationSubscription?.cancel();

    // Stop all services
    _batteryService.stopListening();
    _lightService.stopListening();
    _magnetometerService.stopListening();
    _gyroscopeService.stopListening();
    _proximityService.stopListening();
    _pressureService.stopListening();
    _soundService.stopListening();
    _orientationService.stopListening();
    _accelerometerService.stopListening();
    _linearAccelerationService.stopListening();
    _locationService.stopListening();

    super.dispose();
  }
}
