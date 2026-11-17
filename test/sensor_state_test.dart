import 'dart:async';

import 'package:aninitools/services/sensors/sound_service.dart';
import 'package:aninitools/services/beat_detector.dart';
import 'package:aninitools/viewmodels/compass_viewmodel.dart';
import 'package:aninitools/viewmodels/sensor_viewmodel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const codec = StandardMethodCodec();
  var permission = 2;
  var locationRequests = 0, microphoneRequests = 0;
  var failRecording = false, recording = false;
  var failAmplitude = 0;
  dynamic streamSettings;
  Map<dynamic, dynamic>? recordingConfig;
  String recorderId = '';

  void event(String channel, Object value) {
    binding.channelBuffers.push(
      channel,
      codec.encodeSuccessEnvelope(value),
      (_) {},
    );
  }

  void missing(String name) {
    binding.channelBuffers.push(
      'dev.fluttercommunity.plus/sensors/$name',
      codec.encodeErrorEnvelope(code: 'NO_SENSOR'),
      (_) {},
    );
  }

  setUp(() {
    permission = 2;
    locationRequests = microphoneRequests = 0;
    failRecording = recording = false;
    failAmplitude = 0;
    streamSettings = null;
    recordingConfig = null;
    for (final channel in [
      'dev.fluttercommunity.plus/sensors/method',
      'dev.fluttercommunity.plus/sensors/accelerometer',
      'dev.fluttercommunity.plus/sensors/user_accel',
      'dev.fluttercommunity.plus/sensors/magnetometer',
      'dev.fluttercommunity.plus/sensors/gyroscope',
      'dev.fluttercommunity.plus/sensors/barometer',
      'dev.fluttercommunity.plus/charging',
      'proximity_sensor',
      'proximity_sensor_enable',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/battery'),
      (call) async => call.method == 'getBatteryLevel' ? 50 : 'discharging',
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (call) async {
        switch (call.method) {
          case 'checkPermission':
            return permission;
          case 'requestPermission':
            locationRequests++;
            return 2;
          case 'isLocationServiceEnabled':
            return true;
          case 'getCurrentPosition':
            throw PlatformException(code: 'LOCATION_UPDATE_FAILURE');
          default:
            return null;
        }
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator_updates'),
      (call) async {
        if (call.method == 'listen') streamSettings = call.arguments;
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async {
        final id = (call.arguments as Map)['recorderId'];
        for (final channel in ['events', 'eventsRecord']) {
          messenger.setMockMethodCallHandler(
            MethodChannel('com.llfbandit.record/$channel/$id'),
            (_) async => null,
          );
        }
        switch (call.method) {
          case 'hasPermission':
            microphoneRequests++;
            return true;
          case 'isRecording':
            return recording;
          case 'startStream':
            if (failRecording) {
              throw PlatformException(
                code: 'record',
                message: 'Controlled start failure',
              );
            }
            recordingConfig = call.arguments as Map;
            recorderId = id as String;
            recording = true;
            return null;
          case 'stop':
            recording = false;
            return null;
          case 'getAmplitude':
            if (failAmplitude > 0) {
              failAmplitude--;
              throw PlatformException(code: 'AMPLITUDE_FAILED');
            }
            return {'current': -30.0, 'max': 0.0};
          default:
            return null;
        }
      },
    );
  });

  test('microphone level keeps the native digital reference', () async {
    final level = await SoundService().decibelStream.first.timeout(
      const Duration(seconds: 2),
    );
    expect(level, -30);
    expect(recordingConfig!['audioInterruption'], 2);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  testWidgets(
    'unavailable sensors never become valid zeros; listeners share hardware',
    (tester) async {
      final first = SensorViewModel(), second = SensorViewModel();
      await first.initialize(
        sensors: {'magnetic', 'orientation', 'linearAcceleration'},
      );
      await second.initialize(sensors: {'magnetic'});
      await tester.pump();
      expect(first.isSensorAvailable('magnetic'), isFalse);
      expect(first.isSensorAvailable('orientation'), isFalse);
      expect(locationRequests, 0);
      expect(microphoneRequests, 0);
      event('dev.fluttercommunity.plus/sensors/magnetometer', [
        0.0,
        30.0,
        0.0,
        1.0,
      ]);
      event('dev.fluttercommunity.plus/sensors/accelerometer', [
        0.0,
        9.8,
        0.0,
        1.0,
      ]);
      event('dev.fluttercommunity.plus/sensors/user_accel', [
        0.0,
        0.0,
        0.0,
        1.0,
      ]);
      await tester.pump(const Duration(milliseconds: 200));
      expect(first.isSensorAvailable('magnetic'), isTrue);
      expect(first.isSensorAvailable('orientation'), isTrue);
      expect(first.linearAccelMagnitude, 0);
      final version = first.sampleVersion('magnetic');
      first.toggleCard('magnetic');
      expect(first.sampleVersion('magnetic'), version);
      first.dispose();
      await tester.pump();
      event('dev.fluttercommunity.plus/sensors/magnetometer', [
        0.0,
        40.0,
        0.0,
        2.0,
      ]);
      await tester.pump(const Duration(milliseconds: 200));
      expect(second.magneticField, 40);
      missing('magnetometer');
      await tester.pump(const Duration(milliseconds: 200));
      expect(second.isSensorAvailable('magnetic'), isFalse);
      second.dispose();
      await tester.pump();
    },
  );

  testWidgets('compass needs magnetic data, but tilt does not need it', (
    tester,
  ) async {
    permission = 0;
    final compass = CompassViewModel();
    await compass.initialize();
    await tester.pump();
    event('dev.fluttercommunity.plus/sensors/accelerometer', [
      0.0,
      0.0,
      9.8,
      1.0,
    ]);
    await tester.pump(const Duration(milliseconds: 40));
    expect(compass.hasHeading, isFalse);
    expect(locationRequests, 0);
    event('dev.fluttercommunity.plus/sensors/magnetometer', [
      0.0,
      30.0,
      0.0,
      1.0,
    ]);
    event('dev.fluttercommunity.plus/sensors/accelerometer', [
      0.0,
      0.0,
      9.8,
      2.0,
    ]);
    await tester.pump(const Duration(milliseconds: 40));
    expect(compass.hasHeading, isTrue);
    missing('magnetometer');
    await tester.pump(const Duration(milliseconds: 40));
    expect(compass.hasHeading, isFalse);
    compass.dispose();
    await tester.pump();
  });

  testWidgets(
    'failed location acquisition ends loading; old speed is marked stale',
    (tester) async {
      final model = SensorViewModel();
      await model.initialize(sensors: {'gps'});
      await tester.pump();
      expect(model.isLoadingGPS, isFalse);
      expect(model.isSensorAvailable('gps'), isFalse);
      expect(model.gpsStatus, contains('No GPS signal'));
      expect(streamSettings['distanceFilter'], 0);
      event('flutter.baseflow.com/geolocator_updates', {
        'latitude': 3.1,
        'longitude': 101.7,
        'altitude': 0.0,
        'accuracy': 5.0,
        'speed': 20 / 3.6,
      });
      await tester.pump(const Duration(milliseconds: 200));
      expect(model.gpsSpeedKmh, closeTo(20, .001));
      expect(model.gpsSpeedFresh, isTrue);
      await tester.pump(const Duration(seconds: 6));
      expect(model.gpsSpeedFresh, isFalse);
      event('flutter.baseflow.com/geolocator_updates', {
        'latitude': 3.1,
        'longitude': 101.7,
        'altitude': 0.0,
        'accuracy': 5.0,
        'speed': 0.0,
      });
      await tester.pump(const Duration(milliseconds: 200));
      expect(model.gpsSpeed, 0);
      expect(model.gpsSpeedFresh, isTrue);
      model.dispose();
      await tester.pump();
    },
  );

  testWidgets('a short bump between UI updates still counts as a peak', (
    tester,
  ) async {
    final model = SensorViewModel();
    await model.initialize(sensors: {'linearAcceleration'});
    await tester.pump();
    event('dev.fluttercommunity.plus/sensors/user_accel', [0.0, 6.0, 0.0, 1.0]);
    event('dev.fluttercommunity.plus/sensors/user_accel', [0.0, -4.0, 0.0, 2.0]);
    event('dev.fluttercommunity.plus/sensors/user_accel', [0.0, 0.3, 0.0, 3.0]);
    double? peak, yMax, yMin;
    model.addListener(() {
      peak = model.linearAccelPeakMagnitude;
      yMax = model.linearAccelYMax;
      yMin = model.linearAccelYMin;
    });
    await tester.pump(const Duration(milliseconds: 200));
    expect(model.linearAccelMagnitude, closeTo(0.3, 1e-9));
    expect(peak, closeTo(6, 1e-9));
    expect(yMax, closeTo(6, 1e-9));
    expect(yMin, closeTo(-4, 1e-9));
    model.dispose();
    await tester.pump();
  });

  testWidgets('location retry restarts a stream another screen holds', (
    tester,
  ) async {
    permission = 0; // the platform stream refuses to start
    final dashboard = SensorViewModel(), tool = SensorViewModel();
    await dashboard.initialize(sensors: {'gps'});
    await tester.pump();
    expect(streamSettings, isNull);
    permission = 2;
    await tool.initialize(sensors: {'gps'});
    await tester.pump();
    expect(streamSettings, isNotNull);
    dashboard.dispose();
    tool.dispose();
    await tester.pump();
  });

  test('one failed level read does not close the microphone', () async {
    final model = SensorViewModel();
    try {
      await model.initialize(sensors: {'sound'});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(model.isSensorAvailable('sound'), isTrue);
      failAmplitude = 1;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(model.isSensorAvailable('sound'), isTrue);
      expect(recording, isTrue);
    } finally {
      model.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });

  test('enabling the microphone during an interruption says why', () async {
    final dashboard = SensorViewModel(), tool = SensorViewModel();
    try {
      await dashboard.initialize(sensors: {'sound'});
      await tool.initialize(sensors: {'sound'});
      await Future<void>.delayed(const Duration(milliseconds: 300));
      event('com.llfbandit.record/events/$recorderId', 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tool.retrySoundMonitoring();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(tool.isRequestingSound, isFalse);
      expect(tool.isSensorAvailable('sound'), isFalse);
    } finally {
      dashboard.dispose();
      tool.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  });

  test(
    'microphone retry recovers both active consumers after failure',
    () async {
      failRecording = true;
      final dashboard = SensorViewModel(), tool = SensorViewModel();
      try {
        await dashboard.initialize(sensors: {'sound'});
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tool.initialize(sensors: {'sound'});
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(dashboard.isSensorAvailable('sound'), isFalse);
        failRecording = false;
        await tool.retrySoundMonitoring();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(tool.isSensorAvailable('sound'), isTrue);
        expect(dashboard.isSensorAvailable('sound'), isTrue);
        expect(tool.isRequestingSound, isFalse);
      } finally {
        dashboard.dispose();
        tool.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    },
  );

  test('microphone start errors remain unavailable and allow retry', () async {
    failRecording = true;
    final model = SensorViewModel();
    final failed = Completer<void>();
    model.addListener(() {
      if (model.soundStatus.contains('unavailable') && !failed.isCompleted) {
        failed.complete();
      }
    });
    try {
      await model.initialize(sensors: {'sound'});
      await failed.future.timeout(const Duration(seconds: 2));
      expect(model.isSensorAvailable('sound'), isFalse);
      expect(model.isRequestingSound, isFalse);
      final ready = Completer<void>();
      model.addListener(() {
        if (model.isSensorAvailable('sound') && !ready.isCompleted) {
          ready.complete();
        }
      });
      failRecording = false;
      await model.retrySoundMonitoring();
      await ready.future.timeout(const Duration(seconds: 2));
      expect(model.decibel, -30);
    } finally {
      model.dispose();
    }
  });

  test(
    'interrupted microphone stops samples and recovers without a tap',
    () async {
      final model = SensorViewModel();
      try {
        await model.initialize(sensors: {'sound'});
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(model.isSensorAvailable('sound'), isTrue);
        event('com.llfbandit.record/events/$recorderId', 0);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(model.isSensorAvailable('sound'), isFalse);
        final pausedVersion = model.sampleVersion('sound');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(model.sampleVersion('sound'), pausedVersion);
        event('com.llfbandit.record/events/$recorderId', 1);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(model.isSensorAvailable('sound'), isTrue);
        recording = false;
        event('com.llfbandit.record/events/$recorderId', 2);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(model.isSensorAvailable('sound'), isFalse);
        await model.retrySoundMonitoring();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(model.isSensorAvailable('sound'), isTrue);
      } finally {
        model.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    },
  );

  test(
    'beat capture resumes after interruption and releases the light',
    () async {
      final sustain = <bool>[];
      var stopped = 0;
      final detector = BeatDetector(
        onSustainChange: sustain.add,
        onStopped: () => stopped++,
      );
      try {
        expect(await detector.start(), BeatDetectorStartResult.success);
        expect(recordingConfig!['audioInterruption'], 2);
        final audio = Uint8List.fromList([
          255,
          127,
          255,
          127,
          255,
          127,
          255,
          127,
        ]);
        event('com.llfbandit.record/eventsRecord/$recorderId', audio);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(sustain, [true]);
        event('com.llfbandit.record/events/$recorderId', 0);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(sustain, [true, false]);
        event('com.llfbandit.record/eventsRecord/$recorderId', audio);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(sustain, [true, false]);
        event('com.llfbandit.record/events/$recorderId', 1);
        event('com.llfbandit.record/eventsRecord/$recorderId', audio);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(sustain, [true, false, true]);
        binding.channelBuffers.push(
        'com.llfbandit.record/events/$recorderId',
          codec.encodeErrorEnvelope(code: 'CAPTURE_FAILED'),
          (_) {},
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(sustain, [true, false, true, false]);
        // A failure stops capture by itself; the screen must hear about it once.
        expect(stopped, 1);
        await detector.stop();
        expect(stopped, 1);
      } finally {
        await detector.dispose();
      }
    },
  );
}
