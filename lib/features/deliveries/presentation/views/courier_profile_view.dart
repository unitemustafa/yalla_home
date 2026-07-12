import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/network_image_or_placeholder.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../../../core/presentation/widgets/snackbars/custom_snackbar.dart';
import '../../../../core/theme/app_theme_controller.dart';
import '../../domain/courier_account.dart';
import '../controllers/courier_profile_controller.dart';

class CourierProfileView extends StatefulWidget {
  const CourierProfileView({
    super.key,
    required this.activeOrders,
    required this.deliveredOrders,
    required this.onActiveOrdersTap,
    required this.onDeliveredSummaryTap,
    required this.onLogout,
    this.controller,
  });

  final int activeOrders;
  final int deliveredOrders;
  final VoidCallback onActiveOrdersTap;
  final VoidCallback onDeliveredSummaryTap;
  final VoidCallback onLogout;
  final CourierProfileController? controller;

  @override
  State<CourierProfileView> createState() => _CourierProfileViewState();
}

class _CourierProfileViewState extends State<CourierProfileView> {
  late CourierProfileController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? CourierProfileController();
    _ownsController = widget.controller == null;
    _controller.loadAccountIfNeeded();
  }

  @override
  void didUpdateWidget(covariant CourierProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    if (_ownsController) _controller.dispose();
    _controller = widget.controller ?? CourierProfileController();
    _ownsController = widget.controller == null;
    _controller.loadAccountIfNeeded();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightSurface;

    return ColoredBox(
      color: backgroundColor,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: _controller.refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth >= 760
                    ? 680.0
                    : constraints.maxWidth;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: _ProfileBody(
                          activeOrders: widget.activeOrders,
                          deliveredOrders: widget.deliveredOrders,
                          onActiveOrdersTap: widget.onActiveOrdersTap,
                          onDeliveredSummaryTap: widget.onDeliveredSummaryTap,
                          onLogout: widget.onLogout,
                          controller: _controller,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.activeOrders,
    required this.deliveredOrders,
    required this.onActiveOrdersTap,
    required this.onDeliveredSummaryTap,
    required this.onLogout,
    required this.controller,
    required this.isDark,
  });

  final int activeOrders;
  final int deliveredOrders;
  final VoidCallback onActiveOrdersTap;
  final VoidCallback onDeliveredSummaryTap;
  final VoidCallback onLogout;
  final CourierProfileController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final account = controller.account;
    final errorMessage = controller.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTopBar(
          title: 'حساب المندوب',
          subtitle: 'بيانات التشغيل والحساب',
        ),
        const SizedBox(height: 18),
        if (controller.isLoading && !controller.hasLoaded)
          const _ProfileLoading()
        else if (errorMessage != null && account == null)
          _ProfileError(message: errorMessage, onRetry: controller.loadAccount)
        else ...[
          _CourierHero(account: account),
          if (account?.profile == null) ...[
            const SizedBox(height: 12),
            const _IncompleteProfileNotice(),
          ],
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
                  label: 'طلبات مسلّمة',
                  color: AppColors.success,
                  onTap: onDeliveredSummaryTap,
                ),
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            _InlineProfileError(
              message: errorMessage,
              onRetry: controller.loadAccount,
            ),
          ],
          const SizedBox(height: 22),
          _SettingsSection(
            title: 'بيانات تشغيل المندوب',
            isDark: isDark,
            children: [
              _SettingsInfoTile(
                icon: AppIcons.location,
                title: 'مدينة الخدمة',
                subtitle:
                    account?.profile?.serviceCityLabel ??
                    'مدينة الخدمة غير محددة',
                accentColor: AppColors.info,
              ),
              _SettingsDivider(isDark: isDark),
              _SettingsInfoTile(
                icon: AppIcons.tick_circle,
                title: 'حالة استقبال الطلبات',
                subtitle:
                    account?.profile?.availabilityLabel ?? 'الحالة غير معروفة',
                accentColor: _availabilityColor(account?.profile?.isAvailable),
              ),
              _SettingsDivider(isDark: isDark),
              _SettingsInfoTile(
                icon: AppIcons.truck_fast,
                title: 'نوع المركبة',
                subtitle: account?.profile?.vehicleTypeLabel ?? 'غير محدد',
                accentColor: AppColors.primary,
              ),
              _SettingsDivider(isDark: isDark),
              _SettingsInfoTile(
                icon: AppIcons.info_circle,
                title: 'رقم اللوحة',
                subtitle: account?.profile?.plateNumberLabel ?? 'غير محدد',
                accentColor: AppColors.warning,
              ),
              _SettingsDivider(isDark: isDark),
              _SettingsInfoTile(
                icon: AppIcons.receipt_text,
                title: 'الحد الأقصى للطلبات النشطة',
                subtitle: account?.profile?.maxActiveOrdersLabel ?? 'غير محدد',
                accentColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsSection(
            title: 'إعدادات التطبيق',
            isDark: isDark,
            children: const [_ThemeModeTile()],
          ),
          const SizedBox(height: 18),
          _LogoutButton(onPressed: () => _showLogoutDialog(context, onLogout)),
        ],
      ],
    );
  }

  Color _availabilityColor(bool? isAvailable) {
    return switch (isAvailable) {
      true => AppColors.success,
      false => AppColors.error,
      null => AppColors.warning,
    };
  }

  void _showLogoutDialog(BuildContext context, VoidCallback onLogout) {
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

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      key: Key('courier_profile_loading'),
      height: 260,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('courier_profile_error'),
      height: 320,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.warning_2, color: AppColors.error, size: 34),
            const SizedBox(height: 10),
            Text(
              'تعذر تحميل بيانات حساب المندوب',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            ElevatedButton(
              key: const Key('courier_profile_retry'),
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineProfileError extends StatelessWidget {
  const _InlineProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.warning_2, color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            key: const Key('courier_profile_inline_retry'),
            onPressed: onRetry,
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }
}

class _IncompleteProfileNotice extends StatelessWidget {
  const _IncompleteProfileNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('courier_profile_missing_notice'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.warning_2, color: AppColors.warning, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'بيانات تشغيل المندوب غير مكتملة.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierHero extends StatelessWidget {
  const _CourierHero({required this.account});

  final CourierAccount? account;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = AuthSession.instance.absoluteUrl(account?.avatarUrl);

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
          _CourierAvatar(avatarUrl: avatarUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account?.displayName ?? 'مندوب Yalla Home',
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
                  account?.secondaryLabel ?? 'بيانات الاتصال غير محددة',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourierAvatar extends StatelessWidget {
  const _CourierAvatar({required this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: NetworkImageOrPlaceholder(
          url: avatarUrl,
          placeholderAsset: AppAssets.defaultCourier,
          imageKey: const Key('courier_profile_avatar_network'),
          placeholderKey: const Key('courier_profile_avatar_fallback'),
          fit: BoxFit.cover,
          semanticLabel: 'صورة المندوب',
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

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile();

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
                  'ثيم التطبيق',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
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
            ),
          ),
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

    return Padding(
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
