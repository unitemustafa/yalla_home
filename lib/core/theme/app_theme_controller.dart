import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController extends ValueNotifier<ThemeMode> {
  AppThemeController._() : super(ThemeMode.system);

  static final AppThemeController instance = AppThemeController._();
  static const String _storageKey = 'app.theme_mode';

  Future<void> loadSavedTheme() async {
    final preferences = await SharedPreferences.getInstance();
    value = _themeModeFromCode(preferences.getString(_storageKey));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (value == mode) return;

    value = mode;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, _codeFromThemeMode(mode));
  }

  Future<void> setDarkTheme(bool enabled) {
    return setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }

  static ThemeMode _themeModeFromCode(String? code) {
    return switch (code) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _codeFromThemeMode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
