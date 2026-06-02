import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Modern Notifier to control ThemeMode
class ThemeNotifier extends Notifier<ThemeMode> {
  static const String _themeKey = 'theme_mode';
  late SharedPreferences _prefs;

  @override
  ThemeMode build() {
    _initTheme();
    return ThemeMode.system;
  }

  Future<void> _initTheme() async {
    _prefs = await SharedPreferences.getInstance();
    final themeIndex = _prefs.getInt(_themeKey);
    if (themeIndex != null) {
      state = ThemeMode.values[themeIndex];
    }
  }

  Future<void> toggleTheme(bool isDarkMode) async {
    final newMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    _prefs = await SharedPreferences.getInstance();
    await _prefs.setInt(_themeKey, newMode.index);
  }
}

// Global Provider
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
