import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../../../core/presentation/widgets/snackbars/custom_snackbar.dart';
import '../../data/courier_orders_api.dart';
import '../../domain/courier_notification.dart';
import '../../domain/courier_order.dart';
import '../controllers/courier_notifications_controller.dart';

class CourierNotificationsView extends StatefulWidget {
  const CourierNotificationsView({
    super.key,
    required this.onOrderTap,
    required this.onUnreadCountChanged,
    this.controller,
    this.ordersApi = const CourierOrdersApi(),
  });

  final ValueChanged<CourierOrder> onOrderTap;
  final ValueChanged<int> onUnreadCountChanged;
  final CourierNotificationsController? controller;
  final CourierOrdersApi ordersApi;

  @override
  State<CourierNotificationsView> createState() =>
      _CourierNotificationsViewState();
}

class _CourierNotificationsViewState extends State<CourierNotificationsView> {
  late final CourierNotificationsController _controller =
      widget.controller ?? CourierNotificationsController();
  late final bool _ownsController = widget.controller == null;
  bool _openingOrder = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.loadNotificationsIfNeeded();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    widget.onUnreadCountChanged(_controller.unreadCount);
    setState(() {});
  }

  Future<void> _markAllRead() async {
    try {
      await _controller.markAllRead();
      if (!mounted) return;
      CustomSnackBar.showSuccess(
        context: context,
        title: 'تم تعليم الإشعارات كمقروءة',
      );
    } catch (error) {
      if (!mounted) return;
      CustomSnackBar.showError(context: context, title: error.toString());
    }
  }

  Future<bool> _confirmDelete(CourierNotification notification) async {
    try {
      await _controller.deleteNotification(notification);
      if (!mounted) return true;
      CustomSnackBar.showSuccess(context: context, title: 'تم حذف الإشعار');
      return true;
    } catch (error) {
      if (!mounted) return false;
      CustomSnackBar.showError(context: context, title: error.toString());
      return false;
    }
  }

  Future<CourierNotification> _markReadIfNeeded(
    CourierNotification notification,
  ) async {
    if (notification.isRead) return notification;
    try {
      return await _controller.markRead(notification);
    } catch (error) {
      if (mounted) {
        CustomSnackBar.showError(context: context, title: error.toString());
      }
      rethrow;
    }
  }

  Future<void> _openNotification(CourierNotification notification) async {
    CourierNotification visibleNotification = notification;
    if (!notification.isRead) {
      try {
        visibleNotification = await _markReadIfNeeded(notification);
      } catch (_) {
        return;
      }
    }
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _NotificationDetailSheet(
          data: visibleNotification,
          openingOrder: _openingOrder,
          onOrderTap: () async {
            Navigator.pop(sheetContext);
            await _openLinkedOrder(visibleNotification);
          },
        );
      },
    );
  }

  Future<void> _openLinkedOrder(CourierNotification notification) async {
    final orderId = notification.orderId;
    if (orderId == null || orderId.isEmpty) {
      CustomSnackBar.showError(
        context: context,
        title: 'هذا الطلب لم يعد متاحا لك.',
      );
      return;
    }

    if (_openingOrder) return;
    setState(() => _openingOrder = true);
    try {
      final readNotification = await _markReadIfNeeded(notification);
      final id = readNotification.orderId ?? orderId;
      final order = await widget.ordersApi.loadOrder(id);
      if (!mounted) return;
      widget.onOrderTap(order);
    } catch (_) {
      if (!mounted) return;
      CustomSnackBar.showError(
        context: context,
        title: 'هذا الطلب لم يعد متاحا لك.',
      );
    } finally {
      if (mounted) setState(() => _openingOrder = false);
    }
  }

  Future<void> _refresh() => _controller.refreshNotifications();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : const Color(0xFFF7F8FB);
    final notifications = _controller.notifications;
    final isInitialLoading =
        _controller.isLoading &&
        notifications.isEmpty &&
        _controller.errorMessage == null;

    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxContentWidth = constraints.maxWidth >= 760
              ? 680.0
              : constraints.maxWidth;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageTopBar(
                          title: 'الإشعارات',
                          subtitle: 'تنبيهات الطلبات وحالة التسليم',
                          showBackButton: true,
                          backButtonKey: const Key(
                            'courier_notifications_back_button',
                          ),
                          onBackPressed: () => Navigator.maybePop(context),
                          actions: [
                            _NotificationActionButton(
                              key: const Key('courier_notifications_mark_all'),
                              isDark: isDark,
                              icon: AppIcons.tick_circle,
                              tooltip: 'تعليم الكل كمقروء',
                              onPressed:
                                  _controller.unreadCount == 0 ||
                                      _controller.isMarkingAllRead
                                  ? null
                                  : _markAllRead,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _NotificationSummary(
                          isDark: isDark,
                          unreadCount: _controller.unreadCount,
                          totalCount: notifications.length,
                        ),
                        const SizedBox(height: 22),
                        if (isInitialLoading)
                          const _NotificationsLoadingView()
                        else if (_controller.errorMessage != null &&
                            notifications.isEmpty)
                          _NotificationsErrorView(
                            message: _controller.errorMessage!,
                            onRetry: _controller.loadNotifications,
                          )
                        else if (notifications.isEmpty)
                          const _EmptyNotificationsView()
                        else ...[
                          Text(
                            'اليوم',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          for (final notification in notifications)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Dismissible(
                                key: ValueKey(
                                  'courier_notification_${notification.id}',
                                ),
                                direction: DismissDirection.endToStart,
                                background:
                                    const _NotificationDismissBackground(),
                                confirmDismiss: (_) =>
                                    _confirmDelete(notification),
                                child: _NotificationCard(
                                  data: notification,
                                  isDark: isDark,
                                  isDeleting: _controller.isDeleting(
                                    notification,
                                  ),
                                  onTap: () => _openNotification(notification),
                                  onDelete: () => _confirmDelete(notification),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NotificationActionButton extends StatelessWidget {
  const _NotificationActionButton({
    super.key,
    required this.isDark,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final bool isDark;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDark ? AppColors.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Icon(
              icon,
              size: 21,
              color: isEnabled
                  ? (isDark ? Colors.white : Colors.black)
                  : mutedColor.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationSummary extends StatelessWidget {
  const _NotificationSummary({
    required this.isDark,
    required this.unreadCount,
    required this.totalCount,
  });

  final bool isDark;
  final int unreadCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.16 : 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              AppIcons.notification_bing,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unreadCount == 0
                      ? 'كل الإشعارات مقروءة'
                      : '$unreadCount إشعار غير مقروء',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'إجمالي $totalCount إشعار.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.data,
    required this.isDark,
    required this.isDeleting,
    required this.onTap,
    required this.onDelete,
  });

  final CourierNotification data;
  final bool isDark;
  final bool isDeleting;
  final VoidCallback onTap;
  final Future<bool> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final panelColor = isDark ? AppColors.darkCardColor : Colors.white;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = !data.isRead
        ? AppColors.primary.withValues(alpha: 0.20)
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05));
    final color = _notificationColor(data);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isDeleting ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_notificationIcon(data), color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.displayTitle,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!data.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        IconButton(
                          key: ValueKey(
                            'courier_notification_delete_${data.id}',
                          ),
                          tooltip: 'حذف الإشعار',
                          visualDensity: VisualDensity.compact,
                          onPressed: isDeleting
                              ? null
                              : () async {
                                  await onDelete();
                                },
                          icon: isDeleting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  AppIcons.trash,
                                  size: 19,
                                  color: AppColors.error,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.displayMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.relativeTimeLabel(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _NotificationDetailSheet extends StatelessWidget {
  const _NotificationDetailSheet({
    required this.data,
    required this.openingOrder,
    required this.onOrderTap,
  });

  final CourierNotification data;
  final bool openingOrder;
  final Future<void> Function() onOrderTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? AppColors.darkCardColor : Colors.white;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
    final color = _notificationColor(data);

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.14),
              blurRadius: 28,
              offset: const Offset(0, -12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mutedColor.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _notificationIcon(data),
                      color: color,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تفاصيل الإشعار',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: mutedColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          data.displayTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          data.hasLinkedOrder
                              ? '#${data.orderId} • ${data.relativeTimeLabel()}'
                              : data.relativeTimeLabel(),
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: mutedColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                data.displayMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (data.isBlocking || data.isResolved) ...[
                const SizedBox(height: 16),
                _NotificationMetaRow(
                  icon: data.isResolved
                      ? AppIcons.tick_circle
                      : AppIcons.warning_2,
                  label: 'الحالة',
                  value: data.isResolved ? 'تم الحل' : 'يتطلب متابعة',
                  color: data.isResolved
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ],
              if (data.hasLinkedOrder) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: openingOrder ? null : onOrderTap,
                    icon: const Icon(AppIcons.receipt_text, size: 18),
                    label: const Text(
                      'فتح الطلب',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationMetaRow extends StatelessWidget {
  const _NotificationMetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationDismissBackground extends StatelessWidget {
  const _NotificationDismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(end: 22),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: AlignmentDirectional.centerEnd,
      child: const Icon(AppIcons.trash, color: Colors.white, size: 24),
    );
  }
}

class _NotificationsLoadingView extends StatelessWidget {
  const _NotificationsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _NotificationsErrorView extends StatelessWidget {
  const _NotificationsErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          const Icon(AppIcons.warning_2, size: 30, color: AppColors.error),
          const SizedBox(height: 10),
          Text(
            'تعذر تحميل الإشعارات',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            key: const Key('courier_notifications_retry'),
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotificationsView extends StatelessWidget {
  const _EmptyNotificationsView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          Icon(AppIcons.notification_bing, size: 30, color: mutedColor),
          const SizedBox(height: 10),
          Text(
            'لا توجد إشعارات حاليا',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'أي تنبيه جديد بخصوص الطلبات سيظهر هنا.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _notificationIcon(CourierNotification notification) {
  return switch (notification.type) {
    'order_assigned' => AppIcons.box,
    _ => AppIcons.notification_bing,
  };
}

Color _notificationColor(CourierNotification notification) {
  if (notification.isBlocking && !notification.isResolved) {
    return AppColors.warning;
  }
  return switch (notification.type) {
    'order_assigned' => AppColors.info,
    _ => AppColors.primary,
  };
}
