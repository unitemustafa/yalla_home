import 'package:flutter/material.dart';

import '../../features/auth/presentation/views/login_view.dart';
import '../../features/deliveries/presentation/views/courier_shell_view.dart';
import '../../features/splash/presentation/views/splash_view.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.splash => _buildRoute(const SplashView(), settings),
      AppRoutes.login => _buildRoute(const LoginView(), settings),
      AppRoutes.dashboard => _buildRoute(const CourierShellView(), settings),
      _ => _buildRoute(const LoginView(), settings),
    };
  }

  static MaterialPageRoute<dynamic> _buildRoute(
    Widget page,
    RouteSettings settings,
  ) {
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
