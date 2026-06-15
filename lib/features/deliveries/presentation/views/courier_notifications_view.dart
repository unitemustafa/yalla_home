import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/formatters/app_currency.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../../../core/presentation/widgets/snackbars/custom_snackbar.dart';
import '../../domain/courier_order.dart';

class CourierNotificationsView extends StatefulWidget {
  const CourierNotificationsView({
    super.key,
    required this.orders,
    required this.onOrderTap,
    required this.onUnreadCountChanged,
  });

  final List<CourierOrder> orders;
  final ValueChanged<CourierOrder> onOrderTap;
  final ValueChanged<int> onUnreadCountChanged;

  @override
  State<CourierNotificationsView> createState() =>
      _CourierNotificationsViewState();
}

class _CourierNotificationsViewState extends State<CourierNotificationsView> {
  final Set<String> _readIds = <String>{};
  final Set<String> _dismissedIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyUnreadCountChanged();
    });
  }

  @override
  void didUpdateWidget(covariant CourierNotificationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orders != widget.orders) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyUnreadCountChanged();
      });
    }
  }

  List<_CourierNotificationData> get _notifications {
    final orderNotifications = widget.orders
        .map(_CourierNotificationData.fromOrder)
        .where((notification) => !_dismissedIds.contains(notification.id))
        .map(
          (notification) => notification.copyWith(
            unread: notification.unread && !_readIds.contains(notification.id),
          ),
        )
        .toList();

    orderNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orderNotifications;
  }

  int get _unreadCount {
    return _notifications.where((notification) => notification.unread).length;
  }

  void _markAllRead() {
    setState(() {
      _readIds.addAll(_notifications.map((notification) => notification.id));
    });
    _notifyUnreadCountChanged();

    CustomSnackBar.showSuccess(
      context: context,
      title: 'تم تعليم الإشعارات كمقروءة',
    );
  }

  void _deleteNotification(_CourierNotificationData notification) {
    setState(() {
      _dismissedIds.add(notification.id);
      _readIds.add(notification.id);
    });
    _notifyUnreadCountChanged();

    CustomSnackBar.showError(context: context, title: 'تم حذف الإشعار');
  }

  void _openNotification(_CourierNotificationData notification) {
    setState(() => _readIds.add(notification.id));
    _notifyUnreadCountChanged();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _NotificationDetailSheet(
          data: notification.copyWith(unread: false),
          onOrderTap: () {
            Navigator.pop(sheetContext);
            widget.onOrderTap(notification.order);
          },
        );
      },
    );
  }

  void _notifyUnreadCountChanged() {
    widget.onUnreadCountChanged(_unreadCount);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : const Color(0xFFF7F8FB);
    final notifications = _notifications;

    return ColoredBox(
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxContentWidth = constraints.maxWidth >= 760
              ? 680.0
              : constraints.maxWidth;

          return ListView(
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
                        actions: [
                          _NotificationActionButton(
                            isDark: isDark,
                            icon: AppIcons.tick_circle,
                            tooltip: 'تعليم الكل كمقروء',
                            onPressed: _unreadCount == 0 ? null : _markAllRead,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _NotificationSummary(
                        isDark: isDark,
                        unreadCount: _unreadCount,
                        totalCount: notifications.length,
                      ),
                      const SizedBox(height: 22),
                      if (notifications.isEmpty)
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
                              key: ValueKey(notification.id),
                              direction: DismissDirection.endToStart,
                              background:
                                  const _NotificationDismissBackground(),
                              onDismissed: (_) =>
                                  _deleteNotification(notification),
                              child: _NotificationCard(
                                data: notification,
                                isDark: isDark,
                                onTap: () => _openNotification(notification),
                              ),
                            ),
                          ),
                      ],
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
}

class _NotificationActionButton extends StatelessWidget {
  const _NotificationActionButton({
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
                  'إجمالي $totalCount تنبيه للطلبات الحالية والمسلمة.',
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
    required this.onTap,
  });

  final _CourierNotificationData data;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final panelColor = isDark ? AppColors.darkCardColor : Colors.white;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final borderColor = data.unread
        ? AppColors.primary.withValues(alpha: 0.20)
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
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
                  color: data.color.withValues(alpha: isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, color: data.color, size: 21),
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
                            data.title,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (data.unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.message,
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
                      data.timeLabel,
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
    required this.onOrderTap,
  });

  final _CourierNotificationData data;
  final VoidCallback onOrderTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? AppColors.darkCardColor : Colors.white;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final textColor = isDark ? Colors.white : AppColors.lightTextPrimary;

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
                      color: data.color.withValues(alpha: isDark ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(data.icon, color: data.color, size: 25),
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
                          data.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: textColor,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${data.order.id} • ${data.timeLabel}',
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
                data.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  height: 1.55,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _NotificationMetaRow(
                icon: AppIcons.location,
                label: 'المنطقة',
                value: data.order.area,
                color: data.color,
              ),
              const SizedBox(height: 8),
              _NotificationMetaRow(
                icon: AppIcons.money_3,
                label: 'قيمة الطلب',
                value: AppCurrency.format(data.order.total),
                color: AppColors.success,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onOrderTap,
                  icon: const Icon(AppIcons.receipt_text, size: 18),
                  label: const Text(
                    'فتح الطلب',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
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
            'مفيش إشعارات حاليا',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'أي تنبيه جديد بخصوص الطلبات هيظهر هنا.',
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

class _CourierNotificationData {
  const _CourierNotificationData({
    required this.id,
    required this.order,
    required this.icon,
    required this.title,
    required this.message,
    required this.timeLabel,
    required this.createdAt,
    required this.color,
    required this.unread,
  });

  factory _CourierNotificationData.fromOrder(CourierOrder order) {
    if (order.isDelivered) {
      final deliveredAt = order.deliveredAt ?? order.createdAt;
      return _CourierNotificationData(
        id: 'delivered-${order.id}',
        order: order,
        icon: AppIcons.tick_circle,
        title: 'تم تسليم ${order.id}',
        message:
            'تم تسجيل تسليم طلب ${order.customerName} بقيمة ${AppCurrency.format(order.total)}.',
        timeLabel: _relativeTime(deliveredAt),
        createdAt: deliveredAt,
        color: AppColors.success,
        unread: false,
      );
    }

    final isUrgent =
        order.expectedDeliveryAt.difference(DateTime.now()).inMinutes <= 45;

    return _CourierNotificationData(
      id: 'assigned-${order.id}',
      order: order,
      icon: isUrgent ? AppIcons.warning_2 : AppIcons.box,
      title: isUrgent ? 'طلب قريب التسليم' : 'طلب جديد مطلوب استلامه',
      message:
          '${order.id} في ${order.area} مع ${order.itemCount} منتجات بقيمة ${AppCurrency.format(order.total)}.',
      timeLabel: _relativeTime(order.createdAt),
      createdAt: order.createdAt,
      color: isUrgent ? AppColors.warning : AppColors.info,
      unread: true,
    );
  }

  final String id;
  final CourierOrder order;
  final IconData icon;
  final String title;
  final String message;
  final String timeLabel;
  final DateTime createdAt;
  final Color color;
  final bool unread;

  _CourierNotificationData copyWith({bool? unread}) {
    return _CourierNotificationData(
      id: id,
      order: order,
      icon: icon,
      title: title,
      message: message,
      timeLabel: timeLabel,
      createdAt: createdAt,
      color: color,
      unread: unread ?? this.unread,
    );
  }

  static String _relativeTime(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) return 'الآن';
    if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
    if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة';
    return 'منذ ${difference.inDays} يوم';
  }
}
