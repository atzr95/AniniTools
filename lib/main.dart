import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'models/prefs.dart';
import 'models/reporting_preferences.dart';
import 'views/home_screen.dart';
import 'views/tools/spirit_level_screen.dart';
import 'views/tools/metal_detector_screen.dart';
import 'views/tools/decibel_meter_screen.dart';
import 'views/tools/altitude_calculator_screen.dart';
import 'views/tools/vibration_analyzer_screen.dart';
import 'views/tools/accelerometer_screen.dart';
import 'viewmodels/sensor_viewmodel.dart';

/// Filter errors to exclude expected sensor unavailability issues.
/// Matches the error message only. The stack text is not checked: it holds
/// file names like sensor_viewmodel.dart, which would hide real crashes there.
bool _shouldReportError(dynamic error) {
  final errorString = error.toString().toLowerCase();

  // List of patterns to ignore (sensor-related errors)
  final ignoredPatterns = [
    'sensor',
    'not available',
    'unavailable',
    'permission denied',
    'magnetometer',
    'gyroscope',
    'accelerometer',
    'proximity',
    'pressure',
    'barometer',
    'location service',
    'gps',
  ];

  // Check if error matches any ignored patterns
  for (final pattern in ignoredPatterns) {
    if (errorString.contains(pattern)) {
      return false; // Don't report this error
    }
  }

  return true; // Report all other errors
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase Analytics
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  final reportingPrefs = await SharedPreferences.getInstance();
  var previouslyEnabled = reportingPrefs.getBool('optional_app_reports') ?? false;
  final reporting = ReportingPreferences(
    reportingPrefs,
    apply: (enabled) async {
      // Native defaults also keep collection off before Dart can read consent.
      await analytics.setConsent(
        analyticsStorageConsentGranted: enabled,
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
      );
      await analytics.setAnalyticsCollectionEnabled(enabled);
      if (enabled && !previouslyEnabled) {
        // Do not upload crashes cached before this choice was given.
        await FirebaseCrashlytics.instance.deleteUnsentReports();
      }
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
      if (!enabled) {
        await analytics.resetAnalyticsData();
        await FirebaseCrashlytics.instance.deleteUnsentReports();
      }
      previouslyEnabled = enabled;
    },
  );
  try {
    await reporting.initialize();
  } catch (_) {
    // Optional reports must not prevent the tools from opening.
    if (kDebugMode) debugPrint('Could not apply the reporting choice');
  }

  // Initialize Firebase Crashlytics with error filtering
  FlutterError.onError = (errorDetails) {
    // This handler replaces Flutter's default, which is what prints errors.
    // In debug builds, print them again so layout overflows etc. stay visible.
    if (kDebugMode) FlutterError.presentError(errorDetails);
    // Filter out sensor-related errors
    if (reporting.enabled && _shouldReportError(errorDetails.exception)) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    }
  };

  // Pass all uncaught asynchronous errors to Crashlytics with filtering
  PlatformDispatcher.instance.onError = (error, stack) {
    // Returning true below marks the error handled, which hides it. Print it in debug builds.
    if (kDebugMode) debugPrint('Uncaught async error: $error\n$stack');
    if (reporting.enabled && _shouldReportError(error)) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };

  // Initialize SharedPreferences
  await Prefs().init();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider.value(
      value: reporting,
      child: AniniToolsApp(analytics: analytics),
    ),
  );
}

class AniniToolsApp extends StatelessWidget {
  final FirebaseAnalytics analytics;

  const AniniToolsApp({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AniniTools',
      debugShowCheckedModeBanner: false,
      // Dark only — there is no theme toggle in the app.
      theme: _buildTheme(),
      navigatorObservers: [FirebaseAnalyticsObserver(analytics: analytics)],
      home: const HomeScreen(),
      routes: {
        '/spirit-level': (_) =>
            _withSensors(const SpiritLevelScreen(), {'orientation'}),
        '/metal-detector': (_) =>
            _withSensors(const MetalDetectorScreen(), {'magnetic'}),
        '/decibel-meter': (_) =>
            _withSensors(const DecibelMeterScreen(), {'sound'}),
        '/altitude-calculator': (_) =>
            _withSensors(const AltitudeCalculatorScreen(), {'pressure', 'gps'}),
        '/vibration-analyzer': (_) => _withSensors(
          const VibrationAnalyzerScreen(),
          {'linearAcceleration'},
        ),
        '/g-force-meter': (_) => _withSensors(const AccelerometerScreen(), {
          'linearAcceleration',
          'gps',
        }),
      },
    );
  }

  /// Every tool screen consumes SensorViewModel. `create:` (not `.value`) so
  /// the view model is disposed when the route pops instead of leaking sensors.
  /// Safe even though the Sensors screen stays mounted underneath: the sensor
  /// services start on their first stream listener and stop on their last, so
  /// disposing this view model only drops its own subscriptions.
  static Widget _withSensors(Widget child, Set<String> sensors) =>
      ChangeNotifierProvider(
        create: (_) => SensorViewModel()..initialize(sensors: sensors),
        child: child,
      );

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    );
  }
}
