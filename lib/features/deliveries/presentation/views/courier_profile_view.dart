import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/connectivity/internet_status_controller.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../../../core/presentation/widgets/snackbars/custom_snackbar.dart';
import '../../../../core/theme/app_theme_controller.dart';

class CourierProfileView extends StatelessWidget {
  const CourierProfileView({
    super.key,
    required this.activeOrders,
    required this.deliveredOrders,
    required this.onActiveOrdersTap,
    required this.onDeliveredSummaryTap,
    required this.onLogout,
  });

  final int activeOrders;
  final int deliveredOrders;
  final VoidCallback onActiveOrdersTap;
  final VoidCallback onDeliveredSummaryTap;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightSurface;

    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth >= 760
              ? 680.0
              : constraints.maxWidth;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PageTopBar(
                        title: 'حساب المندوب',
                        subtitle: 'بيانات الشيفت والحالة الحالية',
                      ),
                      const SizedBox(height: 18),
                      const _CourierHero(),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _CourierStat(
                              icon: AppIcons.receipt_text,
                              value: '$activeOrders',
                              label: 'طلبات نشطة',
                              color: AppColors.primary,
                              onTap: onActiveOrdersTap,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CourierStat(
                              icon: AppIcons.tick_circle,
                              value: '$deliveredOrders',
                              label: 'إجمالي التسليم',
                              color: AppColors.success,
                              onTap: onDeliveredSummaryTap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _SettingsSection(
                        title: 'إعدادات التشغيل',
                        isDark: isDark,
                        children: [
                          const _SettingsInfoTile(
                            icon: AppIcons.location,
                            title: 'منطقة الشيفت',
                            subtitle: 'القاهرة • متاح للتوصيل',
                            accentColor: AppColors.success,
                          ),
                          _SettingsDivider(isDark: isDark),
                          const _ThemeModeTile(),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _LogoutButton(
                        onPressed: () => _showLogoutDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('تسجيل الخروج', textAlign: TextAlign.center),
          content: const Text(
            'متأكد إنك عايز تسجل خروج؟',
            textAlign: TextAlign.center,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      onLogout();
                    },
                    child: const Text('تأكيد'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CourierHero extends StatelessWidget {
  const _CourierHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.70)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(AppAssets.blackLogo, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'كابتن مصطفى',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      AppIcons.tick_circle,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'شيفت القاهرة • متاح للتوصيل',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                const _StatusBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    final statusController = InternetStatusScope.maybeOf(context);

    if (statusController == null) {
      return const _StatusBadgeContent(label: 'Online', isOffline: false);
    }

    return AnimatedBuilder(
      animation: statusController,
      builder: (context, _) {
        final isOffline = statusController.isOffline;

        return _StatusBadgeContent(
          label: isOffline ? 'Offline' : 'Online',
          isOffline: isOffline,
        );
      },
    );
  }
}

class _StatusBadgeContent extends StatelessWidget {
  const _StatusBadgeContent({required this.label, required this.isOffline});

  final String label;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOffline
            ? AppColors.error.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CourierStat extends StatelessWidget {
  const _CourierStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
    required this.isDark,
  });

  final String title;
  final List<Widget> children;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05),
    );
  }
}

class _ThemeModeTile extends _ThemeModeTileBase {
  const _ThemeModeTile() : super();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.instance,
      builder: (context, mode, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final mutedColor = isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showThemeSheet(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _SettingsTileIcon(
                    icon: _themeModeIcon(mode),
                    color: _themeModeAccentColor(mode),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ثيم التطبيق',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _themeModeLabel(mode),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: mutedColor,
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded, color: mutedColor, size: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showThemeSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMode = AppThemeController.instance.value;
    const themeModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkCardColor : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return _ThemeSelectionSheet(
          title: 'ثيم التطبيق',
          children: [
            for (final themeMode in themeModes) ...[
              _ThemeOptionTile(
                title: _themeModeLabel(themeMode),
                subtitle: _themeModeSubtitle(themeMode),
                icon: _themeModeIcon(themeMode),
                accentColor: _themeModeAccentColor(themeMode),
                isSelected: currentMode == themeMode,
                onTap: () {
                  Navigator.pop(sheetContext);
                  AppThemeController.instance.setThemeMode(themeMode);
                  CustomSnackBar.showSuccess(
                    context: context,
                    title: 'تم تحديث الثيم',
                  );
                },
              ),
              if (themeMode != themeModes.last) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'النظام',
      ThemeMode.light => 'فاتح',
      ThemeMode.dark => 'داكن',
    };
  }

  String _themeModeSubtitle(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'استخدم إعدادات الجهاز.',
      ThemeMode.light => 'استخدم الثيم الفاتح دائمًا.',
      ThemeMode.dark => 'استخدم الثيم الداكن دائمًا.',
    };
  }

  IconData _themeModeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.smartphone_rounded,
      ThemeMode.light => Icons.wb_sunny_rounded,
      ThemeMode.dark => Icons.nightlight_round,
    };
  }

  Color _themeModeAccentColor(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => AppColors.info,
      ThemeMode.light => AppColors.warning,
      ThemeMode.dark => const Color(0xFF8B5CF6),
    };
  }
}

class _ThemeSelectionSheet extends StatelessWidget {
  const _ThemeSelectionSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.32),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : const Color(0xFFF7F8FB),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              _SettingsTileIcon(icon: icon, color: accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(AppIcons.tick_circle, color: accentColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeTileBase extends StatelessWidget {
  const _ThemeModeTileBase();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ثيم التطبيق',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'غيّر شكل التطبيق من هنا',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const _SettingsTileIcon(
                icon: AppIcons.setting_2,
                color: AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppThemeController.instance,
            builder: (context, mode, _) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final borderColor = isDark
                  ? AppColors.darkCardColor
                  : Colors.grey.shade300;

              Widget buildSegment({
                required ThemeMode value,
                required String label,
                required IconData icon,
                bool isFirst = false,
                bool isLast = false,
              }) {
                final isSelected = mode == value;
                final bgActive = isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent;
                final fgActive = isDark
                    ? Colors.white
                    : AppColors.lightTextPrimary;

                return Expanded(
                  child: InkWell(
                    onTap: () =>
                        AppThemeController.instance.setThemeMode(value),
                    borderRadius: BorderRadius.horizontal(
                      right: isFirst ? const Radius.circular(28) : Radius.zero,
                      left: isLast ? const Radius.circular(28) : Radius.zero,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: bgActive,
                        borderRadius: BorderRadius.horizontal(
                          right: isFirst
                              ? const Radius.circular(28)
                              : Radius.zero,
                          left: isLast
                              ? const Radius.circular(28)
                              : Radius.zero,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  color: fgActive,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Icon(icon, size: 18, color: fgActive),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    buildSegment(
                      value: ThemeMode.system,
                      label: 'النظام',
                      icon: Icons.smartphone_rounded,
                      isFirst: true,
                    ),
                    Container(width: 1.5, height: 24, color: borderColor),
                    buildSegment(
                      value: ThemeMode.light,
                      label: 'فاتح',
                      icon: Icons.wb_sunny_rounded,
                    ),
                    Container(width: 1.5, height: 24, color: borderColor),
                    buildSegment(
                      value: ThemeMode.dark,
                      label: 'داكن',
                      icon: Icons.nightlight_round,
                      isLast: true,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.icon,
    required this.title,
    required this.accentColor,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _SettingsTileIcon(icon: icon, color: accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
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
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

class _SettingsTileIcon extends StatelessWidget {
  const _SettingsTileIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(AppIcons.logout, size: 19),
        label: const Text('تسجيل الخروج'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
