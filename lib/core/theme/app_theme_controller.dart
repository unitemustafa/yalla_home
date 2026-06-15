import 'package:flutter/material.dart';

class AppThemeController extends ValueNotifier<ThemeMode> {
  AppThemeController._() : super(ThemeMode.system);

  static final AppThemeController instance = AppThemeController._();

  void setThemeMode(ThemeMode mode) {
    value = mode;
  }
}
