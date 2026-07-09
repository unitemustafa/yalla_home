import 'package:flutter/material.dart';

import 'core/auth/auth_session.dart';
import 'yalla_home_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail immediately if a release build was created without
  // the production backend URL.
  AuthSession.apiBaseUrl;

  runApp(const YallaHomeApp());
}
