import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/routing/app_routes.dart';
import '../../data/demo_courier_orders.dart';
import '../../domain/courier_order.dart';
import '../widgets/delivery_confirmation_sheet.dart';
import 'courier_notifications_view.dart';
import 'courier_orders_view.dart';
import 'courier_profile_view.dart';
import 'delivered_history_view.dart';
import 'delivered_summary_view.dart';
import 'order_details_view.dart';

class CourierShellView extends StatefulWidget {
  const CourierShellView({super.key});

  @override
  State<CourierShellView> createState() => _CourierShellViewState();
}

class _CourierShellViewState extends State<CourierShellView> {
  late List<CourierOrder> _orders;
  int _selectedIndex = 0;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _orders = DemoCourierOrders.initialOrders();
  }

  List<CourierOrder> get _activeOrders {
    return _orders.where((order) => !order.isDelivered).toList();
  }

  List<CourierOrder> get _deliveredOrders {
    return _orders.where((order) => order.isDelivered).toList();
  }

  void _markDelivered(String orderId, DeliveryConfirmationResult result) {
    setState(() {
      _orders = [
        for (final order in _orders)
          if (order.id == orderId)
            order.copyWith(
              status: CourierOrderStatus.delivered,
              deliveredAt: DateTime.now(),
              deliveryNote: result.note,
              deliveryProof: result.proof,
            )
          else
            order,
      ];
      _selectedIndex = 1;
    });
  }

  void _logout() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CourierOrdersView(orders: _activeOrders, onDelivered: _markDelivered),
      DeliveredHistoryView(orders: _deliveredOrders),
      CourierNotificationsView(
        orders: _orders,
        onOrderTap: _openOrderDetails,
        onUnreadCountChanged: _updateUnreadNotificationCount,
      ),
      CourierProfileView(
        activeOrders: _activeOrders.length,
        deliveredOrders: _deliveredOrders.length,
        onActiveOrdersTap: () => setState(() => _selectedIndex = 0),
        onDeliveredSummaryTap: _openDeliveredSummary,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: _CourierBottomNavigationBar(
        selectedIndex: _selectedIndex,
        notificationBadgeCount: _unreadNotificationCount,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  void _openDeliveredSummary() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DeliveredSummaryView(orders: _deliveredOrders),
      ),
    );
  }

  void _openOrderDetails(CourierOrder order) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            OrderDetailsView(order: order, onDelivered: _markDelivered),
      ),
    );
  }

  void _updateUnreadNotificationCount(int count) {
    if (_unreadNotificationCount == count) return;
    setState(() => _unreadNotificationCount = count);
  }
}

class _CourierBottomNavigationBar extends StatelessWidget {
  const _CourierBottomNavigationBar({
    required this.selectedIndex,
    required this.notificationBadgeCount,
    required this.onSelected,
  });

  final int selectedIndex;
  final int notificationBadgeCount;
  final ValueChanged<int> onSelected;

  static const _items = [
    _NavigationItemData(
      label: 'الطلبات',
      icon: AppIcons.receipt_text,
      activeIcon: AppIcons.truck_fast,
    ),
    _NavigationItemData(
      label: 'المسلّمة',
      icon: AppIcons.document_text,
      activeIcon: AppIcons.tick_circle,
    ),
    _NavigationItemData(
      label: 'حسابي',
      icon: AppIcons.user,
      activeIcon: AppIcons.profile_circle,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkCardColor : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final navigationItems = [
      _items[0],
      _items[1],
      _NavigationItemData(
        label: 'الإشعارات',
        icon: AppIcons.notification,
        activeIcon: AppIcons.notification_bing,
      ),
      _items[2],
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 78,
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(top: BorderSide(color: borderColor)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(navigationItems.length, (index) {
            return Expanded(
              child: _NavigationBarItem(
                item: navigationItems[index],
                isSelected: selectedIndex == index,
                badgeCount: index == 2 ? notificationBadgeCount : 0,
                onTap: () => onSelected(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavigationBarItem extends StatelessWidget {
  const _NavigationBarItem({
    required this.item,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  final _NavigationItemData item;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = AppColors.lightTextSecondary;
    final labelColor = isSelected ? AppColors.primary : inactiveColor;
    final indicatorColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.11)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: 52,
                    height: 32,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: labelColor,
                      size: 22,
                    ),
                  ),
                  if (badgeCount > 0)
                    PositionedDirectional(
                      top: -4,
                      end: 5,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: labelColor,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItemData {
  const _NavigationItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
