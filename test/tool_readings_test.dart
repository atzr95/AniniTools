import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:aninitools/models/text_style_config.dart';
import 'package:aninitools/viewmodels/sensor_viewmodel.dart';
import 'package:aninitools/views/flashlight/concert_mode_screen.dart';
import 'package:aninitools/views/tools/decibel_meter_screen.dart';
import 'package:aninitools/views/tools/altitude_calculator_screen.dart';
import 'package:aninitools/views/tools/spirit_level_screen.dart';
import 'package:aninitools/views/tools/vibration_analyzer_screen.dart';
import 'package:aninitools/widgets/text_styles/led_matrix_renderer.dart';
import 'package:aninitools/widgets/text_styles/pixel_retro_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FixedSensors extends SensorViewModel {
  @override
  bool isSensorAvailable(String name) => true;
  @override
  double get pitch => math.pi / 18;
  @override
  double get roll => 0;
  @override
  double get accelX => 0;
  @override
  double get accelY => 9.8;
  @override
  double get accelZ => 0;
  @override
  double get decibel => -30;
  @override
  double get pressure => 1012.5;

  @override
  double get linearAccelMagnitude => 0;
  @override
  int sampleVersion(String name) => 1;
}

Widget tool(Widget child) => ChangeNotifierProvider<SensorViewModel>(
  create: (_) => FixedSensors(),
  child: MaterialApp(home: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
  });

  test('favorite colors survive repeated save and load', () {
    var favorite = MessageTemplate('RED', Colors.red, [
      Colors.red,
      Colors.blue,
    ]);
    for (var i = 0; i < 3; i++) {
      favorite = MessageTemplate.fromJson(favorite.toJson());
      expect(favorite.solidColor.toARGB32(), Colors.red.toARGB32());
      expect(favorite.gradientColors.map((color) => color.toARGB32()), [
        Colors.red.toARGB32(),
        Colors.blue.toARGB32(),
      ]);
    }
  });

  testWidgets('a ten-degree slope stays not level until calibrated', (
    tester,
  ) async {
    await tester.pumpWidget(tool(const SpiritLevelScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('NOT LEVEL'), findsOneWidget);
    await tester.tap(find.byTooltip('Calibrate'));
    await tester.pump();
    expect(find.text('LEVEL'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('stationary gravity is not counted as vibration', (tester) async {
    await tester.pumpWidget(tool(const VibrationAnalyzerScreen()));
    final gauge = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<VibrationGaugePainter>()
        .single;
    expect(gauge.vibration, 0);
    expect(find.text('Extreme'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('redraws do not add microphone history samples', (tester) async {
    await tester.pumpWidget(tool(const DecibelMeterScreen()));
    for (var i = 0; i < 20; i++) {
      await tester.pump();
    }
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    final history = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<DecibelHistoryPainter>()
        .single;
    expect(history.data, [-30]);
    await tester.pumpWidget(const SizedBox());
  });

  test('built-in emoji lights up both dot and pixel styles', () async {
    final painters = <CustomPainter>[
      LEDMatrixPainter(
        text: '💜',
        primaryColor: Colors.white,
        config: const LEDMatrixConfig(unlitOpacity: 0),
      ),
      PixelRetroPainter(
        text: '💜',
        primaryColor: Colors.white,
        config: const PixelRetroConfig(showScanlines: false),
      ),
    ];
    for (final painter in painters) {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(300, 150));
      final picture = recorder.endRecording();
      final image = await picture.toImage(300, 150);
      final bytes = (await image.toByteData())!;
      expect(bytes.buffer.asUint8List().any((value) => value != 0), isTrue);
      image.dispose();
      picture.dispose();
    }
  });

  testWidgets('pressure needs elapsed time and sea-level GPS can calibrate', (
    tester,
  ) async {
    await tester.pumpWidget(tool(const AltitudeCalculatorScreen()));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -350),
    );
    await tester.pump();
    expect(find.text('Insufficient data'), findsOneWidget);
    expect(find.text('Collecting 15 min of readings'), findsOneWidget);
    await tester.tap(find.byTooltip('Calibrate from GPS'));
    await tester.pump();
    expect(
      find.textContaining('Calibrated! Sea level pressure: 1012.50'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
