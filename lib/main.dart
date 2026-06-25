import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'models/prefs.dart';
import 'views/home_screen.dart';
import 'views/tools/spirit_level_screen.dart';
import 'views/tools/metal_detector_screen.dart';
import 'views/tools/decibel_meter_screen.dart';
import 'views/tools/altitude_calculator_screen.dart';
import 'views/tools/vibration_analyzer_screen.dart';
import 'views/tools/accelerometer_screen.dart';
import 'viewmodels/sensor_viewmodel.dart';

/// Filter errors to exclude expected sensor unavailability issues
bool _shouldReportError(dynamic error, StackTrace? stack) {
  final errorString = error.toString().toLowerCase();
  final stackString = stack?.toString().toLowerCase() ?? '';

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
    'light sensor',
    'pressure',
    'barometer',
    'location service',
    'gps',
  ];

  // Check if error matches any ignored patterns
  for (final pattern in ignoredPatterns) {
    if (errorString.contains(pattern) || stackString.contains(pattern)) {
      return false; // Don't report this error
    }
  }

  return true; // Report all other errors
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Analytics
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  // Initialize Firebase Crashlytics with error filtering
  FlutterError.onError = (errorDetails) {
    // Filter out sensor-related errors
    if (_shouldReportError(errorDetails.exception, errorDetails.stack)) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    }
  };

  // Pass all uncaught asynchronous errors to Crashlytics with filtering
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_shouldReportError(error, stack)) {
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

  runApp(AniniToolsApp(analytics: analytics));
}

class AniniToolsApp extends StatelessWidget {
  final FirebaseAnalytics analytics;

  const AniniToolsApp({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AniniTools',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: Prefs().darkMode ? ThemeMode.dark : ThemeMode.light,
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        // For tool routes, wrap them with the SensorViewModel from the previous screen
        if (settings.name?.startsWith('/') ?? false) {
          // Try to get SensorViewModel from previous context (if available)
          return MaterialPageRoute(
            settings: settings,
            builder: (context) {
              // Try to get existing SensorViewModel, or create a new one
              SensorViewModel? viewModel;
              try {
                viewModel = Provider.of<SensorViewModel>(context, listen: false);
              } catch (e) {
                // If no provider exists, create a new instance
                viewModel = SensorViewModel()..initialize();
              }

              return ChangeNotifierProvider.value(
                value: viewModel,
                child: _buildToolScreen(settings.name ?? '/'),
              );
            },
          );
        }
        return null;
      },
    );
  }

  /// Build the appropriate tool screen based on route name
  static Widget _buildToolScreen(String routeName) {
    switch (routeName) {
      case '/spirit-level':
        return const SpiritLevelScreen();
      case '/metal-detector':
        return const MetalDetectorScreen();
      case '/decibel-meter':
        return const DecibelMeterScreen();
      case '/altitude-calculator':
        return const AltitudeCalculatorScreen();
      case '/vibration-analyzer':
        return const VibrationAnalyzerScreen();
      case '/g-force-meter':
        return const AccelerometerScreen();
      default:
        return const Scaffold(
          body: Center(child: Text('Screen not found')),
        );
    }
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    );
  }

  ThemeData _buildDarkTheme() {
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
