import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/formatters/app_currency.dart';
import '../../../../core/icons/app_icons.dart';
import '../../domain/courier_order.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showDeliveredMeta = false,
  });

  final CourierOrder order;
  final VoidCallback onTap;
  final bool showDeliveredMeta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? order.status.color.withValues(alpha: 0.28)
        : order.status.color.withValues(alpha: 0.20);
    final panelColor = isDark ? AppColors.darkCardColor : Colors.white;
    final tintColor = order.status.color.withValues(
      alpha: isDark ? 0.12 : 0.05,
    );
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.58)
        : Colors.black.withValues(alpha: 0.54);
    final shadow = isDark
        ? null
        : [
            BoxShadow(
              color: order.status.color.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.2),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [tintColor, panelColor, panelColor],
              stops: const [0, 0.46, 1],
            ),
            boxShadow: shadow,
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: order.status.color.withValues(
                        alpha: isDark ? 0.22 : 0.13,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: order.status.color.withValues(alpha: 0.20),
                      ),
                    ),
                    child: Icon(
                      order.isDelivered
                          ? AppIcons.tick_circle
                          : AppIcons.truck_fast,
                      color: order.status.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _StatusChip(status: order.status, isDark: isDark),
                            Text(
                              order.id,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          order.customerName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 19,
                            height: 1.18,
                            fontWeight: FontWeight.w900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: mutedColor,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 24,
                    color: mutedColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (showDeliveredMeta) ...[
                    Expanded(
                      child: _OrderMeta(
                        icon: AppIcons.tick_circle,
                        label: 'وقت التسليم',
                        value: _formatTime(order.deliveredAt),
                        mutedColor: mutedColor,
                        accentColor: order.status.color,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: _OrderMeta(
                      icon: AppIcons.shopping_bag,
                      label: 'المنتجات',
                      value: '${order.itemCount}',
                      mutedColor: mutedColor,
                      accentColor: order.status.color,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OrderMeta(
                      icon: AppIcons.money_3,
                      label: 'القيمة',
                      value: AppCurrency.format(order.total),
                      mutedColor: mutedColor,
                      accentColor: order.status.color,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '--:--';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isDark});

  final CourierOrderStatus status;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.color.withValues(alpha: 0.18)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({
    required this.icon,
    required this.label,
    required this.value,
    required this.mutedColor,
    required this.accentColor,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color mutedColor;
  final Color accentColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.10 : 0.055),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
