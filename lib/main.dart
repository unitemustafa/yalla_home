import 'package:flutter/material.dart';

import 'core/theme/app_theme_controller.dart';
import 'yalla_home_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppThemeController.instance.loadSavedTheme();
  runApp(const YallaHomeApp());
}
