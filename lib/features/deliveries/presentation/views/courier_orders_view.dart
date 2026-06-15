import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/formatters/app_currency.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../domain/courier_order.dart';
import '../widgets/order_card.dart';
import 'order_details_view.dart';

class CourierOrdersView extends StatefulWidget {
  const CourierOrdersView({
    super.key,
    required this.orders,
    required this.onDelivered,
  });

  final List<CourierOrder> orders;
  final OrderDeliveredHandler onDelivered;

  @override
  State<CourierOrdersView> createState() => _CourierOrdersViewState();
}

class _CourierOrdersViewState extends State<CourierOrdersView> {
  CourierOrderStatus? _selectedStatus;

  List<CourierOrder> get _filteredOrders {
    final status = _selectedStatus;
    if (status == null) return widget.orders;
    return widget.orders.where((order) => order.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final orders = _filteredOrders;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: orders.isEmpty ? 4 : orders.length + 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const PageTopBar(
            title: 'طلبات التوصيل',
            subtitle: 'الطلبات المطلوب تسليمها اليوم',
          );
        }

        if (index == 1) {
          return _OrdersSummaryCard(orders: widget.orders);
        }

        if (index == 2) {
          return _StatusFilters(
            selectedStatus: _selectedStatus,
            onChanged: (status) => setState(() => _selectedStatus = status),
          );
        }

        if (orders.isEmpty) {
          return const _EmptyOrdersState();
        }

        final order = orders[index - 3];
        return OrderCard(order: order, onTap: () => _openDetails(order));
      },
    );
  }

  void _openDetails(CourierOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            OrderDetailsView(order: order, onDelivered: widget.onDelivered),
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
    final activeCount = orders.length;
    final assignedCount = orders
        .where((order) => order.status == CourierOrderStatus.assigned)
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
            value: '$assignedCount',
            label: CourierOrderStatus.assigned.label,
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

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.selectedStatus, required this.onChanged});

  final CourierOrderStatus? selectedStatus;
  final ValueChanged<CourierOrderStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final filters = <({String label, CourierOrderStatus? status})>[
      (label: 'الكل', status: null),
      (
        label: CourierOrderStatus.assigned.label,
        status: CourierOrderStatus.assigned,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            ChoiceChip(
              label: Text(filter.label),
              selected: selectedStatus == filter.status,
              onSelected: (_) => onChanged(filter.status),
              showCheckmark: false,
              selectedColor: AppColors.primary.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                color: selectedStatus == filter.status
                    ? AppColors.primary
                    : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w900,
              ),
              side: BorderSide(
                color: selectedStatus == filter.status
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  const _EmptyOrdersState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(
            AppIcons.filter_search,
            size: 30,
            color: AppColors.lightTextSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد طلبات بهذا الفلتر',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
