import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../services/sensors/battery_service.dart';
import '../services/sensors/magnetometer_service.dart';
import '../services/sensors/gyroscope_service.dart';
import '../services/sensors/proximity_service.dart';
import '../services/sensors/pressure_service.dart';
import '../services/sensors/sound_service.dart';
import '../services/sensors/orientation_service.dart';
import '../services/sensors/accelerometer_service.dart';
import '../services/sensors/linear_acceleration_service.dart';
import '../services/sensors/location_service.dart';
import '../utils/capped_list.dart';

/// Owns a screen's sensor listeners. Availability means data arrived, not just permission.
class SensorViewModel extends ChangeNotifier {
  final _batteryService = BatteryService();
  final _magnetometerService = MagnetometerService();
  final _gyroscopeService = GyroscopeService();
  final _proximityService = ProximityService();
  final _pressureService = PressureService();
  final _soundService = SoundService();
  final _orientationService = OrientationService();
  final _accelerometerService = AccelerometerService();
  final _linearAccelerationService = LinearAccelerationService();
  final _locationService = LocationService();

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription? _decibelSubscription,
      _pitchSubscription,
      _locationSubscription;
  Timer? _uiUpdateTimer, _gpsStaleTimer;
  bool _hasDataToUpdate = false, _disposed = false;
  bool _requestingSound = false, _requestingLocation = false;

  int _batteryLevel = 0;
  String _batteryStatus = 'Unknown';
  bool _isCharging = false;
  double _magneticField = 0;
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0, _gyroMagnitude = 0;
  bool _isNear = false;
  double _pressure = 0;
  double _decibel = -160, _pitchFrequency = 0;
  String _pitchNote = '--';
  double _pitch = 0, _roll = 0;
  double _accelX = 0, _accelY = 0, _accelZ = 0, _accelMagnitude = 0;
  double _linearAccelY = 0, _linearAccelMagnitude = 0;
  double _linearAccelPeakMagnitude = 0, _linearAccelYMax = 0;
  double _linearAccelYMin = 0;
  double _latitude = 0, _longitude = 0, _altitude = 0, _gpsSpeed = 0;
  bool _hasLocationPermission = false,
      _isLoadingGPS = false,
      _gpsSpeedFresh = false;
  String _gpsStatus = 'Location access needed';
  bool _soundPermissionDenied = false;
  String _soundStatus = 'Enable microphone to read sound levels and pitch';

  final Map<String, bool> _expandedCards = {};
  final Map<String, bool> _sensorAvailability = {};
  final Map<String, int> _sampleVersions = {};
  final Map<String, List<double>> _graphData = {
    'magnetic': [],
    'decibel': [],
    'pitch': [],
    'gyroscope': [],
    'accelerometer': [],
  };

  int get batteryLevel => _batteryLevel;
  String get batteryStatus => _batteryStatus;
  bool get isCharging => _isCharging;
  double get magneticField => _magneticField;
  List<double> get magneticGraphData => _graphData['magnetic']!;
  double get gyroX => _gyroX;
  double get gyroY => _gyroY;
  double get gyroZ => _gyroZ;
  double get gyroMagnitude => _gyroMagnitude;
  List<double> get gyroscopeGraphData => _graphData['gyroscope']!;
  bool get isNear => _isNear;
  double get pressure => _pressure;
  double get decibel => _decibel;
  double get pitchFrequency => _pitchFrequency;
  String get pitchNote => _pitchNote;
  List<double> get decibelGraphData => _graphData['decibel']!;
  List<double> get pitchGraphData => _graphData['pitch']!;
  double get pitch => _pitch;
  double get roll => _roll;
  double get accelX => _accelX;
  double get accelY => _accelY;
  double get accelZ => _accelZ;
  double get accelMagnitude => _accelMagnitude;
  List<double> get accelerometerGraphData => _graphData['accelerometer']!;
  double get linearAccelY => _linearAccelY;
  double get linearAccelMagnitude => _linearAccelMagnitude;

  /// Extremes since the last UI update. Sensors fire faster than the 200 ms
  /// update, so tools read peaks from these instead of the latest value.
  double get linearAccelPeakMagnitude => _linearAccelPeakMagnitude;
  double get linearAccelYMax => _linearAccelYMax;
  double get linearAccelYMin => _linearAccelYMin;
  double get latitude => _latitude;
  double get longitude => _longitude;
  double get altitude => _altitude;
  double get gpsSpeed => _gpsSpeed;
  double get gpsSpeedKmh => _gpsSpeed * 3.6;
  bool get gpsSpeedFresh => _gpsSpeedFresh;
  bool get hasLocationPermission => _hasLocationPermission;
  bool get isLoadingGPS => _isLoadingGPS;
  String get gpsStatus => _gpsStatus;
  bool get soundPermissionDenied => _soundPermissionDenied;
  String get soundStatus => _soundStatus;
  bool get isRequestingSound => _requestingSound;

  bool isCardExpanded(String name) => _expandedCards[name] ?? false;
  bool isSensorAvailable(String name) => _sensorAvailability[name] ?? false;

  /// A new version is a new measurement; screen redraws never advance it.
  int sampleVersion(String name) => _sampleVersions[name] ?? 0;

  /// The dashboard starts only unprotected sensors. Each tool names what it uses.
  Future<void> initialize({
    Set<String> sensors = const {
      'battery',
      'magnetic',
      'gyroscope',
      'proximity',
      'pressure',
      'orientation',
      'accelerometer',
      'linearAcceleration',
    },
  }) async {
    _uiUpdateTimer ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_hasDataToUpdate && !_disposed) {
        _hasDataToUpdate = false;
        notifyListeners();
        // Listeners have read this window's extremes; start the next one.
        _linearAccelPeakMagnitude = _linearAccelMagnitude;
        _linearAccelYMax = _linearAccelYMin = _linearAccelY;
      }
    });
    if (sensors.contains('battery')) {
      _subscriptions.add(
        _batteryService.stream.listen((info) {
          _batteryLevel = info.level;
          _batteryStatus = info.state;
          _isCharging = info.isCharging;
          _received('battery');
        }, onError: (Object error) => _unavailable('battery', error)),
      );
    }
    if (sensors.contains('magnetic')) {
      _subscriptions.add(
        _magnetometerService.stream.listen((field) {
          _magneticField = field;
          _addGraphData('magnetic', field);
          _received('magnetic');
        }, onError: (Object error) => _unavailable('magnetic', error)),
      );
    }
    if (sensors.contains('gyroscope')) {
      _subscriptions.add(
        _gyroscopeService.stream.listen((data) {
          _gyroX = data.x;
          _gyroY = data.y;
          _gyroZ = data.z;
          _gyroMagnitude = data.magnitude;
          _addGraphData('gyroscope', data.magnitude);
          _received('gyroscope');
        }, onError: (Object error) => _unavailable('gyroscope', error)),
      );
    }
    if (sensors.contains('proximity')) {
      _subscriptions.add(
        _proximityService.stream.listen((near) {
          _isNear = near;
          _received('proximity');
        }, onError: (Object error) => _unavailable('proximity', error)),
      );
    }
    if (sensors.contains('pressure')) {
      _subscriptions.add(
        _pressureService.stream.listen((pressure) {
          _pressure = pressure;
          _received('pressure');
        }, onError: (Object error) => _unavailable('pressure', error)),
      );
    }
    if (sensors.contains('orientation')) {
      _subscriptions.add(
        _orientationService.stream.listen((data) {
          _pitch = data.pitch;
          _roll = data.roll;
          _received('orientation');
        }, onError: (Object error) => _unavailable('orientation', error)),
      );
    }
    if (sensors.contains('accelerometer')) {
      _subscriptions.add(
        _accelerometerService.stream.listen((data) {
          _accelX = data.x;
          _accelY = data.y;
          _accelZ = data.z;
          _accelMagnitude = data.magnitude;
          _addGraphData('accelerometer', data.magnitude);
          _received('accelerometer');
        }, onError: (Object error) => _unavailable('accelerometer', error)),
      );
    }
    if (sensors.contains('linearAcceleration')) {
      _subscriptions.add(
        _linearAccelerationService.stream.listen(
          (data) {
            _linearAccelY = data.y;
            _linearAccelMagnitude = data.magnitude;
            if (data.magnitude > _linearAccelPeakMagnitude) {
              _linearAccelPeakMagnitude = data.magnitude;
            }
            if (data.y > _linearAccelYMax) _linearAccelYMax = data.y;
            if (data.y < _linearAccelYMin) _linearAccelYMin = data.y;
            _received('linearAcceleration');
          },
          onError: (Object error) => _unavailable('linearAcceleration', error),
        ),
      );
    }
    await Future.wait([
      if (sensors.contains('gps')) retryLocationPermission(),
      if (sensors.contains('sound')) startSoundMonitoring(),
    ]);
  }

  void _received(String name) {
    if (name == 'sound') _requestingSound = false;
    _sensorAvailability[name] = true;
    _sampleVersions[name] = sampleVersion(name) + 1;
    _hasDataToUpdate = true;
  }

  void _unavailable(String name, Object error) {
    _sensorAvailability[name] = false;
    if (name == 'sound') {
      _requestingSound = false;
      _soundStatus = 'Microphone unavailable. Try again or open settings.';
    }
    _hasDataToUpdate = true;
    debugPrint('$name unavailable: $error');
  }

  Future<void> retryLocationPermission() async {
    if (_requestingLocation || _disposed) return;
    _requestingLocation = true;
    _isLoadingGPS = true;
    _gpsStatus = 'Acquiring GPS signal...';
    _sensorAvailability['gps'] = false;
    _gpsSpeedFresh = false;
    _gpsStaleTimer?.cancel();
    _hasDataToUpdate = true;
    try {
      await _locationSubscription?.cancel();
      _locationSubscription = null;
      final permission = await _locationService.requestPermission();
      if (_disposed) return;
      _hasLocationPermission =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!_hasLocationPermission) {
        _gpsStatus = 'Location access needed';
        return;
      }
      if (!await _locationService.isLocationServiceEnabled()) {
        _gpsStatus = 'Location services OFF';
        return;
      }
      if (_disposed) return;
      _locationSubscription = _locationService.stream.listen(
        _onPosition,
        onError: (Object error) {
          _unavailable('gps', error);
          _gpsSpeedFresh = false;
          _isLoadingGPS = false;
          _gpsStatus = 'Location unavailable. Try again.';
        },
      );
      _locationService.restart();
      // Subscribe first so a stream fix is usable even if the one-shot request fails.
      final version = sampleVersion('gps');
      final position = await _locationService.getCurrentPosition();
      if (_disposed) return;
      if (sampleVersion('gps') == version) {
        if (position != null) {
          _onPosition(position);
        } else {
          _gpsStatus = 'No GPS signal. Try again.';
        }
      }
    } catch (error) {
      _unavailable('gps', error);
      _gpsStatus = 'Location unavailable. Try again.';
    } finally {
      _requestingLocation = false;
      _isLoadingGPS = false;
      _hasDataToUpdate = true;
    }
  }

  void _onPosition(Position position) {
    if (_disposed) return;
    _latitude = position.latitude;
    _longitude = position.longitude;
    _altitude = position.altitude;
    _gpsSpeed = position.speed >= 0 ? position.speed : 0;
    _gpsSpeedFresh = position.speed >= 0;
    _isLoadingGPS = false;
    _gpsStatus = position.accuracy < 10 ? 'Excellent GPS' : 'GPS Ready';
    _received('gps');
    _gpsStaleTimer?.cancel();
    _gpsStaleTimer = Timer(const Duration(seconds: 5), () {
      _gpsSpeedFresh = false;
      _gpsStatus = 'Location reading is old. Try again.';
      _hasDataToUpdate = true;
    });
  }

  Future<void> startSoundMonitoring() async {
    if (_requestingSound || _disposed) return;
    _requestingSound = true;
    _soundStatus = 'Starting microphone...';
    _hasDataToUpdate = true;
    try {
      final granted = await _soundService.requestPermission();
      if (_disposed) return;
      _soundPermissionDenied = !granted;
      if (!granted) {
        _soundStatus =
            'Microphone access needed. Allow access in app settings.';
        _sensorAvailability['sound'] = false;
        return;
      }
      _decibelSubscription?.cancel();
      _pitchSubscription?.cancel();
      _sensorAvailability['sound'] = false;
      _decibelSubscription = _soundService.decibelStream.listen((db) {
        _decibel = db;
        _soundStatus = 'Microphone ready';
        _addGraphData('decibel', db);
        _received('sound');
      }, onError: (Object error) => _unavailable('sound', error));
      _pitchSubscription = _soundService.pitchStream.listen((data) {
        _pitchFrequency = data.frequency;
        _pitchNote = data.noteName;
        _addGraphData('pitch', data.frequency);
        _hasDataToUpdate = true;
      }, onError: (Object error) => _unavailable('sound', error));
      await _soundService.startMonitoring();
    } catch (error) {
      _unavailable('sound', error);
    } finally {
      if (_disposed || _soundPermissionDenied) _requestingSound = false;
      _hasDataToUpdate = true;
    }
  }

  Future<void> retrySoundMonitoring() => startSoundMonitoring();
  Future<bool> openAppSettings() => _locationService.openAppSettings();
  Future<bool> openLocationSettings() =>
      _locationService.openLocationSettings();

  void toggleCard(String name) {
    _expandedCards[name] = !isCardExpanded(name);
    notifyListeners();
  }

  void _addGraphData(String name, double value) =>
      _graphData[name]?.pushCapped(value, 100);

  @override
  void dispose() {
    _disposed = true;
    _uiUpdateTimer?.cancel();
    _gpsStaleTimer?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _decibelSubscription?.cancel();
    _pitchSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}
