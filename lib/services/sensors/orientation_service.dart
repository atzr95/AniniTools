import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Service for calculating device orientation (pitch, roll, azimuth)
/// Uses accelerometer and magnetometer fusion, and owns the compass
/// hard-iron calibration since it holds the raw magnetometer values.
/// Singleton pattern ensures only one instance exists
class OrientationService {
  static final OrientationService _instance = OrientationService._internal();
  factory OrientationService() => _instance;
  OrientationService._internal();

  StreamSubscription? _accelSubscription;
  StreamSubscription? _magnetSubscription;
  // Controller owns the platform subscriptions — see AccelerometerService.
  late final _controller = StreamController<OrientationData>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );
  // 5 Hz — the pre-refactor effective rate (the old 100 ms Timer throttle never
  // bound, the stream default was already 200 ms).
  static const _samplingPeriod = SensorInterval.normalInterval; // 200 ms

  Stream<OrientationData> get stream => _controller.stream;

  double _accelX = 0, _accelY = 0, _accelZ = 9.8;
  double _magX = 0, _magY = 0, _magZ = 0;

  // Hard-iron calibration: min/max bounds collected while calibrating, and the
  // resulting bias subtracted from every magnetometer sample afterwards.
  bool _isCalibrating = false;
  double _magXMin = double.infinity, _magXMax = double.negativeInfinity;
  double _magYMin = double.infinity, _magYMax = double.negativeInfinity;
  double _magZMin = double.infinity, _magZMax = double.negativeInfinity;
  double _magXOffset = 0, _magYOffset = 0, _magZOffset = 0;

  /// True while collecting samples for calibration
  bool get isCalibrating => _isCalibrating;

  /// Start collecting magnetometer bounds (user rotates device in a figure-8)
  void startCalibration() {
    _isCalibrating = true;
    _resetCalibrationBounds();
    debugPrint(
      'Compass calibration started - rotate device in figure-8 pattern',
    );
  }

  /// Stop collecting and apply the measured hard-iron offsets
  void stopCalibration() {
    if (!_isCalibrating) return;
    _isCalibrating = false;

    // Ignore a calibration that never saw a sample on some axis
    if (_magXMin > _magXMax) return;

    _magXOffset = (_magXMax + _magXMin) / 2;
    _magYOffset = (_magYMax + _magYMin) / 2;
    _magZOffset = (_magZMax + _magZMin) / 2;

    debugPrint(
      'Calibration applied - Offsets: X=$_magXOffset, Y=$_magYOffset, Z=$_magZOffset',
    );
  }

  /// Abandon an in-progress calibration without applying it. Offsets from a
  /// previously completed [stopCalibration] stay applied. Callers own this:
  /// _stop() only fires when the listener count hits zero, which a
  /// Compass -> Sensors switch never does (the new screen mounts before the
  /// old one unmounts), so the session would otherwise keep collecting.
  void cancelCalibration() {
    _isCalibrating = false;
    _resetCalibrationBounds();
  }

  void _resetCalibrationBounds() {
    _magXMin = _magYMin = _magZMin = double.infinity;
    _magXMax = _magYMax = _magZMax = double.negativeInfinity;
  }

  void _start() {
    _accelSubscription =
        accelerometerEventStream(samplingPeriod: _samplingPeriod).listen(
          (event) {
            _accelX = event.x;
            _accelY = event.y;
            _accelZ = event.z;

            // Emit from this callback ONLY, and specifically from THIS one.
            // Both sensors run at the same sampling period, so emitting from
            // each would double the event rate; CompassViewModel low-passes
            // once per event, which would halve the heading time constant and
            // make the needle twitchy. The accelerometer is the driver because
            // every device that has a magnetometer has an accelerometer but
            // not the reverse — sensors_plus emits a NO_SENSOR error instead of
            // data when the magnetometer is absent, so driving from the
            // magnetometer froze pitch/roll (and the Spirit Level bubble) at 0
            // on those devices. The magnetometer callback below just stores the
            // axes, which this tick reads, so heading stays just as fresh.
            // Do not "fix" this back.
            _controller.add(_calculateOrientation());
          },
          onError: (error) {
            debugPrint('Accelerometer error: $error');
          },
        );

    // Feeds the azimuth math and the calibration bounds; does not emit.
    _magnetSubscription =
        magnetometerEventStream(samplingPeriod: _samplingPeriod).listen(
          (event) {
            _magX = event.x;
            _magY = event.y;
            _magZ = event.z;

            if (_isCalibrating) {
              _magXMin = math.min(_magXMin, _magX);
              _magXMax = math.max(_magXMax, _magX);
              _magYMin = math.min(_magYMin, _magY);
              _magYMax = math.max(_magYMax, _magY);
              _magZMin = math.min(_magZMin, _magZ);
              _magZMax = math.max(_magZMax, _magZ);
            }
          },
          onError: (error) {
            debugPrint('Magnetometer error: $error');
          },
        );
  }

  /// Calculate orientation (pitch, roll, azimuth) from the latest sensor data
  OrientationData _calculateOrientation() {
    // Calculate pitch and roll from accelerometer (in radians)
    final pitch = math.atan2(
      _accelY,
      math.sqrt(_accelX * _accelX + _accelZ * _accelZ),
    );
    final roll = math.atan2(-_accelX, _accelZ);

    // Magnetometer values with hard-iron bias removed
    final mx = _magX - _magXOffset;
    final my = _magY - _magYOffset;
    final mz = _magZ - _magZOffset;

    // Calculate azimuth (heading) with tilt compensation
    final magXComp = mx * math.cos(pitch) + mz * math.sin(pitch);
    final magYComp =
        mx * math.sin(roll) * math.sin(pitch) +
        my * math.cos(roll) -
        mz * math.sin(roll) * math.cos(pitch);

    // atan2(-x, y) so that 0° is North rather than East
    final azimuth = math.atan2(-magXComp, magYComp) * 180 / math.pi;

    return OrientationData(
      pitch: pitch, // Keep in radians for spirit level
      roll: roll, // Keep in radians for spirit level
      azimuth: azimuth % 360, // Normalized to 0-360
    );
  }

  void _stop() {
    _accelSubscription?.cancel();
    _magnetSubscription?.cancel();
    _accelSubscription = null;
    _magnetSubscription = null;

    // Backstop for an abandoned session (last screen torn down mid figure-8):
    // calibration lives on this singleton, so it must not leave the button lit
    // or extend stale bounds into the next tap.
    cancelCalibration();
  }
}

/// Orientation data class
class OrientationData {
  final double pitch; // Radians for spirit level
  final double roll; // Radians for spirit level
  final double azimuth; // Degrees (0 to 360), magnetic heading

  OrientationData({
    required this.pitch,
    required this.roll,
    required this.azimuth,
  });
}
