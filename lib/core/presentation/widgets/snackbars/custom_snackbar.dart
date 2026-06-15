import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../icons/app_icons.dart';

class CustomSnackBar {
  CustomSnackBar._();

  static void showSuccess({
    required BuildContext context,
    required String title,
    String? message,
  }) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: AppIcons.tick_circle,
      accentColor: AppColors.success,
    );
  }

  static void showWarning({
    required BuildContext context,
    required String title,
    String? message,
  }) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: AppIcons.warning_2,
      accentColor: AppColors.warning,
    );
  }

  static void showError({
    required BuildContext context,
    required String title,
    String? message,
  }) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: AppIcons.danger,
      accentColor: AppColors.error,
    );
  }

  static void showInfo({
    required BuildContext context,
    required String title,
    String? message,
  }) {
    _show(
      context: context,
      title: title,
      message: message,
      icon: AppIcons.info_circle,
      accentColor: AppColors.info,
    );
  }

  static void _show({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color accentColor,
    String? message,
  }) {
    final theme = Theme.of(context);
    final hasMessage = message != null && message.trim().isNotEmpty;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 14),
        padding: EdgeInsets.zero,
        duration: Duration(seconds: hasMessage ? 4 : 2),
        content: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: hasMessage
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ) ??
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (hasMessage) ...[
                      const SizedBox(height: 2),
                      Text(
                        message,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style:
                            theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.76),
                            ) ??
                            TextStyle(
                              color: Colors.white.withValues(alpha: 0.76),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
