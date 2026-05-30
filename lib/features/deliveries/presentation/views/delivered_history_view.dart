import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/presentation/widgets/page_top_bar.dart';
import '../../domain/courier_order.dart';
import '../widgets/order_card.dart';
import 'order_details_view.dart';

class DeliveredHistoryView extends StatelessWidget {
  const DeliveredHistoryView({super.key, required this.orders});

  final List<CourierOrder> orders;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: orders.isEmpty ? 3 : orders.length + 2,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const PageTopBar(
            title: 'المسلّمة اليوم',
            subtitle: 'سجل التسليمات وصور الإثبات',
          );
        }

        if (index == 1) {
          return _HistorySummary(count: orders.length);
        }

        if (orders.isEmpty) {
          return const _EmptyHistoryState();
        }

        final order = orders[index - 2];
        return OrderCard(
          order: order,
          showDeliveredMeta: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => OrderDetailsView(order: order),
              ),
            );
          },
        );
      },
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(AppIcons.tick_circle, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'تم تسليم $count طلب اليوم',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

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
            AppIcons.document_text,
            size: 30,
            color: AppColors.lightTextSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'لسه مفيش تسليمات اليوم',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
