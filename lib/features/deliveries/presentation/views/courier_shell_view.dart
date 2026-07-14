import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/notifications/courier_push_service.dart';
import '../../../../core/routing/app_routes.dart';
import '../../data/courier_notifications_api.dart';
import '../../data/courier_orders_api.dart';
import '../../domain/courier_order.dart';
import '../controllers/courier_notifications_controller.dart';
import '../controllers/courier_profile_controller.dart';
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

class _CourierShellViewState extends State<CourierShellView>
    with WidgetsBindingObserver {
  final _api = const CourierOrdersApi();
  final _notificationsApi = const CourierNotificationsApi();
  final _notificationsController = CourierNotificationsController();
  final _profileController = CourierProfileController();
  List<CourierOrder> _orders = [];
  bool _loading = true;
  String? _loadError;
  int _selectedIndex = 0;
  int _unreadNotificationCount = 0;
  StreamSubscription<CourierPushEvent>? _pushSubscription;
  Timer? _pushRefreshDebounce;
  bool _refreshingRemoteState = false;
  Future<void>? _ordersLoadInFlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOrders();
    unawaited(_profileController.loadAccountIfNeeded());
    unawaited(_refreshUnreadNotificationCount());
    _pushSubscription = CourierPushService.instance.events.listen(_onPushEvent);
    for (final event in CourierPushService.instance.takePendingOpenedEvents()) {
      _onPushEvent(event);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pushSubscription?.cancel();
    _pushRefreshDebounce?.cancel();
    _notificationsController.clear();
    _notificationsController.dispose();
    _profileController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshRemoteState());
    }
  }

  Future<void> _refreshRemoteState() async {
    if (!mounted || _refreshingRemoteState) return;

    _refreshingRemoteState = true;
    try {
      await AuthSession.instance.validateForForeground();
      await Future.wait([
        _loadOrders(),
        _profileController.refresh(),
        _refreshUnreadNotificationCount(),
      ]);
    } catch (_) {
      // A temporary refresh failure must not interrupt the courier workflow.
    } finally {
      _refreshingRemoteState = false;
    }
  }

  void _onPushEvent(CourierPushEvent event) {
    if (!mounted) return;
    final type = event.event;
    if (type == 'courier_account_disabled') return;
    if (event.opened && type == 'courier_order_assigned') {
      unawaited(_openAssignedPush(event.data));
    }
    _pushRefreshDebounce?.cancel();
    _pushRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      if (type == 'courier_profile_updated' ||
          type == 'courier_availability_changed') {
        unawaited(_profileController.refresh());
      } else {
        unawaited(_loadOrders());
      }
      unawaited(_refreshUnreadNotificationCount());
    });
  }

  Future<void> _openAssignedPush(Map<String, dynamic> data) async {
    final orderId = data['order_id']?.toString();
    if (orderId == null || orderId.isEmpty) return;
    try {
      final order = await _api.loadOrder(orderId);
      if (!mounted) return;
      if (!order.isActiveCourierOrder) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يعد هذا الطلب معينًا لك.')),
        );
        await _loadOrders();
        return;
      }
      _openOrderDetails(order);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يعد هذا الطلب متاحًا لك.')),
      );
      await _loadOrders();
    }
  }

  List<CourierOrder> get _activeOrders {
    return _orders.where((order) => order.isActiveCourierOrder).toList();
  }

  List<CourierOrder> get _deliveredOrders {
    return _orders.where((order) => order.isDelivered).toList();
  }

  Future<void> _loadOrders() async {
    final activeLoad = _ordersLoadInFlight;
    if (activeLoad != null) return activeLoad;

    final loadFuture = _performLoadOrders();
    _ordersLoadInFlight = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_ordersLoadInFlight, loadFuture)) {
        _ordersLoadInFlight = null;
      }
    }
  }

  Future<void> _performLoadOrders() async {
    if (mounted) {
      setState(() {
        if (_orders.isEmpty) _loading = true;
        _loadError = null;
      });
    }
    try {
      final orders = await _api.loadOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_orders.isEmpty) _loadError = error.toString();
      });
    }
  }

  Future<void> _refreshOrdersAndUnread() async {
    await Future.wait([_loadOrders(), _refreshUnreadNotificationCount()]);
  }

  Future<CourierOrder> _markPickedUp(String orderId) async {
    final pickedUp = await _api.markPickedUp(orderId);
    if (!mounted) return pickedUp;
    setState(() => _replaceOrder(pickedUp));
    unawaited(_refreshUnreadNotificationCount());
    return pickedUp;
  }

  Future<CourierOrder> _markDelivered(
    String orderId,
    DeliveryConfirmationResult result,
  ) async {
    final delivered = await _api.markDelivered(
      orderId,
      note: result.note,
      proofBytes: result.proofBytes,
      proofName: result.proofName,
    );
    if (!mounted) return delivered;
    setState(() {
      _replaceOrder(delivered);
      _selectedIndex = 1;
    });
    unawaited(_refreshUnreadNotificationCount());
    return delivered;
  }

  void _replaceOrder(CourierOrder updated) {
    _orders = [
      for (final order in _orders)
        if (order.id == updated.id) updated else order,
    ];
  }

  Future<void> _logout() async {
    _notificationsController.clear();
    await AuthSession.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      CourierOrdersView(
        orders: _activeOrders,
        onPickedUp: _markPickedUp,
        onDelivered: _markDelivered,
        onRefresh: _refreshOrdersAndUnread,
        unreadNotificationCount: _unreadNotificationCount,
        onNotificationsPressed: _openNotifications,
      ),
      DeliveredHistoryView(
        orders: _deliveredOrders,
        onRefresh: _refreshOrdersAndUnread,
        unreadNotificationCount: _unreadNotificationCount,
        onNotificationsPressed: _openNotifications,
      ),
      CourierProfileView(
        controller: _profileController,
        activeOrders: _activeOrders.length,
        deliveredOrders: _deliveredOrders.length,
        onActiveOrdersTap: () => setState(() => _selectedIndex = 0),
        onDeliveredSummaryTap: _openDeliveredSummary,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadOrders,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            : IndexedStack(index: _selectedIndex, children: screens),
      ),
      bottomNavigationBar: _CourierBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onSelected: (index) {
          if (_selectedIndex == index) return;
          setState(() => _selectedIndex = index);
          if (index == 2) unawaited(_profileController.refresh());
        },
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
        builder: (_) => OrderDetailsView(
          order: order,
          onPickedUp: _markPickedUp,
          onDelivered: _markDelivered,
        ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    await _notificationsController.refreshNotifications();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: CourierNotificationsView(
              controller: _notificationsController,
              onOrderTap: _openOrderDetails,
              onUnreadCountChanged: _updateUnreadNotificationCount,
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    await _refreshUnreadNotificationCount();
  }

  void _updateUnreadNotificationCount(int count) {
    if (_unreadNotificationCount == count) return;
    setState(() => _unreadNotificationCount = count);
  }

  Future<void> _refreshUnreadNotificationCount() async {
    try {
      final count = await _notificationsApi.loadUnreadCount();
      if (!mounted) return;
      _updateUnreadNotificationCount(count);
    } catch (_) {
      // Notification badge failures should not block the orders experience.
    }
  }
}

class _CourierBottomNavigationBar extends StatelessWidget {
  const _CourierBottomNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
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
          children: List.generate(_items.length, (index) {
            return Expanded(
              child: _NavigationBarItem(
                item: _items[index],
                isSelected: selectedIndex == index,
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
    required this.onTap,
  });

  final _NavigationItemData item;
  final bool isSelected;
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
