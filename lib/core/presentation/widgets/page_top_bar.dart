import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class PageTopBar extends StatelessWidget {
  const PageTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.backButtonKey,
    this.onBackPressed,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final bool showBackButton;
  final Key? backButtonKey;
  final VoidCallback? onBackPressed;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Row(
      children: [
        if (showBackButton) ...[
          _MarketStyleBackButton(
            buttonKey: backButtonKey,
            onPressed: onBackPressed ?? () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[const SizedBox(width: 12), ...actions],
      ],
    );
  }
}

class _MarketStyleBackButton extends StatelessWidget {
  const _MarketStyleBackButton({
    required this.buttonKey,
    required this.onPressed,
  });

  static const _arrowLeft2 = IconData(
    0xe931,
    fontFamily: 'iconsax',
    fontPackage: 'iconsax',
  );
  static const _arrowRight3 = IconData(
    0xe936,
    fontFamily: 'iconsax',
    fontPackage: 'iconsax',
  );

  final Key? buttonKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.92);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final effectiveIcon = Directionality.of(context) == TextDirection.rtl
        ? _arrowRight3
        : _arrowLeft2;

    return Tooltip(
      message: 'رجوع',
      child: Material(
        key: buttonKey,
        color: fillColor,
        shape: CircleBorder(side: BorderSide(color: borderColor)),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(effectiveIcon, size: 21, color: iconColor),
          ),
        ),
      ),
    );
  }
}
