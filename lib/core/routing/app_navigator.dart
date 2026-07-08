import 'package:flutter/material.dart';

import 'app_routes.dart';

class AppNavigator {
  AppNavigator._();

  static final key = GlobalKey<NavigatorState>();

  static void goToLogin() {
    key.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }
}
