import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/auth/auth_session.dart';
import 'core/notifications/courier_push_service.dart';
import 'yalla_home_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail immediately if a release build was created without
  // the production backend URL.
  AuthSession.apiBaseUrl;
  final firebaseReady = await CourierPushService.instance.initialize();
  if (firebaseReady) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );
    if (kReleaseMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
  }

  runApp(const YallaHomeApp());
}
