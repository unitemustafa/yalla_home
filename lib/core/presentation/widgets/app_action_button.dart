import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

enum AppActionButtonVariant { filled, outlined, danger, ghost }

class AppActionButton extends StatelessWidget {
  const AppActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.variant = AppActionButtonVariant.filled,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final AppActionButtonVariant variant;
  final bool fullWidth;

  bool get _enabled => onPressed != null && !isLoading;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: isLoading
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              key: ValueKey(label),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );

    final button = switch (variant) {
      AppActionButtonVariant.filled => ElevatedButton(
        onPressed: _enabled ? onPressed : null,
        child: child,
      ),
      AppActionButtonVariant.outlined => OutlinedButton(
        onPressed: _enabled ? onPressed : null,
        child: child,
      ),
      AppActionButtonVariant.danger => OutlinedButton(
        onPressed: _enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.38)),
        ),
        child: child,
      ),
      AppActionButtonVariant.ghost => TextButton(
        onPressed: _enabled ? onPressed : null,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
        child: child,
      ),
    };

    return SizedBox(width: fullWidth ? double.infinity : null, child: button);
  }
}
