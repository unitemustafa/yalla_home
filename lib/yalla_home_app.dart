import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_constants.dart';
import 'core/auth/password_changed_notifier.dart';
import 'core/auth/session_expired_notifier.dart';
import 'core/presentation/widgets/offline_connection_banner.dart';
import 'core/presentation/widgets/snackbars/custom_snackbar.dart';
import 'core/notifications/courier_push_service.dart';
import 'core/routing/app_navigator.dart';
import 'core/routing/app_router.dart';
import 'core/routing/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_controller.dart';

@visibleForTesting
Future<bool> presentCourierForegroundFeedback(
  CourierPushEvent event, {
  required Future<void> Function(CourierPushEvent event) showBanner,
}) async {
  if (event.opened ||
      event.event.isEmpty ||
      event.event == 'courier_account_disabled') {
    return false;
  }
  await showBanner(event);
  return true;
}

class YallaHomeApp extends StatefulWidget {
  const YallaHomeApp({super.key});

  @override
  State<YallaHomeApp> createState() => _YallaHomeAppState();
}

class _YallaHomeAppState extends State<YallaHomeApp> {
  int _handledSessionExpiredEventId = 0;
  int _handledPasswordChangedEventId = 0;
  StreamSubscription<CourierPushEvent>? _pushSubscription;

  @override
  void initState() {
    super.initState();
    SessionExpiredNotifier.instance.addListener(_handleSessionExpired);
    PasswordChangedNotifier.instance.addListener(_handlePasswordChanged);
    _pushSubscription = CourierPushService.instance.events.listen(
      (event) => unawaited(_handleCourierPushEvent(event)),
    );
  }

  @override
  void dispose() {
    SessionExpiredNotifier.instance.removeListener(_handleSessionExpired);
    PasswordChangedNotifier.instance.removeListener(_handlePasswordChanged);
    _pushSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleCourierPushEvent(CourierPushEvent event) {
    return presentCourierForegroundFeedback(
      event,
      showBanner: _showCourierNotificationBanner,
    );
  }

  Future<void> _showCourierNotificationBanner(CourierPushEvent event) async {
    final currentContext = AppNavigator.key.currentContext;
    final messenger = AppNavigator.scaffoldMessengerKey.currentState;
    if (currentContext == null || messenger == null) return;
    CustomSnackBar.showInfo(
      context: currentContext,
      messenger: messenger,
      title: event.title,
      message: event.body,
    );
    try {
      await HapticFeedback.vibrate();
    } catch (_) {
      // Haptic feedback is optional and must not block notification display.
    }
  }

  void _handlePasswordChanged() {
    final eventId = PasswordChangedNotifier.instance.eventId;
    if (eventId == _handledPasswordChangedEventId) return;
    _handledPasswordChangedEventId = eventId;
    _showPasswordChangedDialog();
  }

  void _showPasswordChangedDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigatorContext = AppNavigator.key.currentContext;
      if (navigatorContext == null) return;

      showDialog<void>(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
          final surfaceColor = isDark ? const Color(0xFF242426) : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black87;
          final mutedColor = isDark
              ? Colors.white.withValues(alpha: 0.66)
              : Colors.black.withValues(alpha: 0.58);

          return AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            icon: const Icon(
              Icons.lock_reset_rounded,
              color: Color(0xFF4F60F6),
              size: 34,
            ),
            title: Text(
              'تم تغيير كلمة المرور',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
            ),
            content: Text(
              'تم تغيير كلمة مرور حسابك. سجّل الدخول بكلمة المرور الجديدة للمتابعة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedColor,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    AppNavigator.goToLogin();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F60F6),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('تسجيل الدخول'),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  void _handleSessionExpired() {
    final eventId = SessionExpiredNotifier.instance.eventId;
    if (eventId == _handledSessionExpiredEventId) return;
    _handledSessionExpiredEventId = eventId;
    AppNavigator.goToLogin();
    _showSessionExpiredDialog();
  }

  void _showSessionExpiredDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigatorContext = AppNavigator.key.currentContext;
      if (navigatorContext == null) return;

      showDialog<void>(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final isDark = theme.brightness == Brightness.dark;
          final surfaceColor = isDark ? const Color(0xFF242426) : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black87;
          final mutedColor = isDark
              ? Colors.white.withValues(alpha: 0.66)
              : Colors.black.withValues(alpha: 0.58);

          return AlertDialog(
            backgroundColor: surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            icon: const Icon(
              Icons.lock_clock_rounded,
              color: Color(0xFF4F60F6),
              size: 34,
            ),
            title: Text(
              'انتهت الجلسة',
              textAlign: TextAlign.center,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
            ),
            content: Text(
              'سجّل دخول تاني عشان تكمل. «افتكرني» بتحافظ على تسجيل دخولك بعد قفل التطبيق.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedColor,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    AppNavigator.goToLogin();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F60F6),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('تسجيل الدخول'),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.instance,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: AppNavigator.key,
          scaffoldMessengerKey: AppNavigator.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: AppConstants.appName,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: OfflineConnectionBanner(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRouter.generateRoute,
        );
      },
    );
  }
}
