import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the visible choice, saved choice and native reporting controls together.
class ReportingPreferences extends ChangeNotifier {
  ReportingPreferences(this._prefs, {required this.apply});

  final SharedPreferences _prefs;
  final Future<void> Function(bool enabled) apply;
  bool _enabled = false;
  bool get enabled => _enabled;

  /// Show the saved choice even if [apply] fails partway, so the switch never
  /// says off while native reporting was already turned on; the user can retry.
  Future<void> initialize() async {
    _enabled = _prefs.getBool('optional_app_reports') ?? false;
    await apply(_enabled);
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      await apply(enabled);
      if (!await _prefs.setBool('optional_app_reports', enabled)) {
        throw StateError('Could not save the reporting choice');
      }
    } catch (_) {
      await apply(_enabled);
      rethrow;
    }
    _enabled = enabled;
    notifyListeners();
  }
}
