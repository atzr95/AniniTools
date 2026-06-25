import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences wrapper - equivalent to Prefs.kt in Kotlin app
/// Stores persistent settings and sensor availability flags
class Prefs {
  static final Prefs _instance = Prefs._internal();
  factory Prefs() => _instance;
  Prefs._internal();

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences (call this in main.dart)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ========================================
  // Sensor Availability Flags
  // ========================================

  bool get sensorGPS => _prefs?.getBool('sensor_gps') ?? true;
  set sensorGPS(bool value) => _prefs?.setBool('sensor_gps', value);

  // ========================================
  // Flashlight Settings
  // ========================================

  bool get flashlightOn => _prefs?.getBool('flashlight_on') ?? false;
  set flashlightOn(bool value) => _prefs?.setBool('flashlight_on', value);

  int get strobeFrequency => _prefs?.getInt('strobe_frequency') ?? 5;
  set strobeFrequency(int value) => _prefs?.setInt('strobe_frequency', value);

  bool get strobeEnabled => _prefs?.getBool('strobe_enabled') ?? false;
  set strobeEnabled(bool value) => _prefs?.setBool('strobe_enabled', value);

  // ========================================
  // Concert Mode Settings
  // ========================================

  String get concertModeText => _prefs?.getString('concert_mode_text') ?? 'ANINI TOOLS';
  set concertModeText(String value) => _prefs?.setString('concert_mode_text', value);

  int get concertModeColor => _prefs?.getInt('concert_mode_color') ?? 0xFFFFFFFF;
  set concertModeColor(int value) => _prefs?.setInt('concert_mode_color', value);

  List<String> get concertModeFavorites => _prefs?.getStringList('concert_mode_favorites') ?? [];
  set concertModeFavorites(List<String> value) => _prefs?.setStringList('concert_mode_favorites', value);

  // ========================================
  // UI Settings
  // ========================================

  int get lastSelectedTab => _prefs?.getInt('last_selected_tab') ?? 0;
  set lastSelectedTab(int value) => _prefs?.setInt('last_selected_tab', value);

  bool get darkMode => _prefs?.getBool('dark_mode') ?? true;
  set darkMode(bool value) => _prefs?.setBool('dark_mode', value);
}
