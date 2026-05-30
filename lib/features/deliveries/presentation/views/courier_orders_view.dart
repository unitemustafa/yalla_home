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
    final activeCount = orders.length;
    final onWayCount = orders
        .where((order) => order.status == CourierOrderStatus.onTheWay)
        .length;
    final totalValue = orders.fold<double>(
      0,
      (total, order) => total + order.total,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          _SummaryPill(
            icon: AppIcons.receipt_text,
            value: '$activeCount',
            label: 'نشط',
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          _SummaryPill(
            icon: AppIcons.truck_fast,
            value: '$onWayCount',
            label: 'في الطريق',
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          _SummaryPill(
            icon: AppIcons.money_3,
            value: AppCurrency.format(totalValue),
            label: 'القيمة',
            color: AppColors.success,
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
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.black.withValues(alpha: 0.52),
                    fontWeight: FontWeight.w700,
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
      (
        label: CourierOrderStatus.pickedUp.label,
        status: CourierOrderStatus.pickedUp,
      ),
      (
        label: CourierOrderStatus.onTheWay.label,
        status: CourierOrderStatus.onTheWay,
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
