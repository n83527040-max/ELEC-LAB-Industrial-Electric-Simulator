import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._preferences, {bool? darkMode})
      : _darkMode = darkMode ?? _preferences.getBool(_themeKey) ?? true;

  static const _themeKey = 'elec_lab_dark_mode';
  final SharedPreferences _preferences;
  bool _darkMode;

  bool get darkMode => _darkMode;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> setDarkMode(bool value) async {
    if (_darkMode == value) return;
    _darkMode = value;
    notifyListeners();
    await _preferences.setBool(_themeKey, value);
  }

  Future<void> toggleTheme() => setDarkMode(!_darkMode);
}
