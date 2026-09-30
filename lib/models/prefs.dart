import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences wrapper - equivalent to Prefs.kt in Kotlin app
/// Stores persistent UI settings
class Prefs {
  static final Prefs _instance = Prefs._internal();
  factory Prefs() => _instance;
  Prefs._internal();

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences (call this in main.dart)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  int get lastSelectedTab => _prefs?.getInt('last_selected_tab') ?? 0;
  set lastSelectedTab(int value) => _prefs?.setInt('last_selected_tab', value);
}
