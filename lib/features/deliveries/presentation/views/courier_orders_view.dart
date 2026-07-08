import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/formatters/app_currency.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../domain/courier_order.dart';
import '../widgets/courier_notifications_button.dart';
import '../widgets/order_card.dart';
import 'order_details_view.dart';

class CourierOrdersView extends StatefulWidget {
  const CourierOrdersView({
    super.key,
    required this.orders,
    required this.onPickedUp,
    required this.onDelivered,
    required this.onRefresh,
    required this.unreadNotificationCount,
    required this.onNotificationsPressed,
  });

  final List<CourierOrder> orders;
  final OrderPickedUpHandler onPickedUp;
  final OrderDeliveredHandler onDelivered;
  final Future<void> Function() onRefresh;
  final int unreadNotificationCount;
  final VoidCallback onNotificationsPressed;

  @override
  State<CourierOrdersView> createState() => _CourierOrdersViewState();
}

class _CourierOrdersViewState extends State<CourierOrdersView> {
  @override
  Widget build(BuildContext context) {
    final orders = widget.orders;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount: orders.isEmpty ? 3 : orders.length + 2,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return PageTopBar(
              title: 'طلبات التوصيل',
              subtitle: 'الطلبات المطلوب تسليمها اليوم',
              actions: [
                CourierNotificationsButton(
                  unreadCount: widget.unreadNotificationCount,
                  onPressed: widget.onNotificationsPressed,
                ),
              ],
            );
          }

          if (index == 1) {
            return _OrdersSummaryCard(orders: widget.orders);
          }

          if (orders.isEmpty) {
            return const _EmptyOrdersState();
          }

          final order = orders[index - 2];
          return OrderCard(order: order, onTap: () => _openDetails(order));
        },
      ),
    );
  }

  void _openDetails(CourierOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsView(
          order: order,
          onPickedUp: widget.onPickedUp,
          onDelivered: widget.onDelivered,
        ),
      ),
    );
  }
}

class _OrdersSummaryCard extends StatelessWidget {
  const _OrdersSummaryCard({required this.orders});

  final List<CourierOrder> orders;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCount = orders
        .where((order) => order.isActiveCourierOrder)
        .length;
    final pickupRequiredCount = orders
        .where((order) => order.requiresPickup)
        .length;
    final totalValue = orders.fold<double>(
      0,
      (total, order) => total + order.total,
    );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCardColor
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          _SummaryPill(
            icon: AppIcons.receipt_text,
            value: '$activeCount',
            label: 'نشط',
            color: AppColors.primary,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _SummaryPill(
            icon: AppIcons.box,
            value: '$pickupRequiredCount',
            label: 'مطلوب الاستلام',
            color: CourierOrderStatus.assigned.color,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _SummaryPill(
            icon: AppIcons.money_3,
            value: AppCurrency.format(totalValue),
            label: 'القيمة',
            color: AppColors.success,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.13 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                maxLines: 1,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  const _EmptyOrdersState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? AppColors.darkCardColor : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final iconColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(AppIcons.filter_search, size: 30, color: iconColor),
          const SizedBox(height: 10),
          Text(
            'لا توجد طلبات نشطة حاليًا',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
