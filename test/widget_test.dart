import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:yalla_home/core/theme/app_theme_controller.dart';
import 'package:yalla_home/features/deliveries/domain/courier_order.dart';
import 'package:yalla_home/features/deliveries/presentation/views/courier_orders_view.dart';
import 'package:yalla_home/features/deliveries/presentation/views/courier_profile_view.dart';
import 'package:yalla_home/features/deliveries/presentation/widgets/delivery_confirmation_sheet.dart';
import 'package:yalla_home/features/deliveries/presentation/widgets/order_card.dart';
import 'package:yalla_home/yalla_home_app.dart';

void main() {
  testWidgets('shows Yalla Home login screen', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const YallaHomeApp());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    expect(find.text('أهلاً يا كابتن'), findsOneWidget);
    expect(
      find.text('رقم الموبايل أو الإيميل أو اسم المستخدم'),
      findsOneWidget,
    );
    expect(find.text('دخول Demo'), findsNothing);
    expect(find.text('تذكرني'), findsOneWidget);
    expect(find.text('الدعم الفني'), findsOneWidget);

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.elementAt(0).controller?.text, isEmpty);
    expect(fields.elementAt(1).controller?.text, isEmpty);

    final rememberMe = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(rememberMe.value, isTrue);

    final supportButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'الدعم الفني'),
    );
    expect(supportButton.onPressed, isNotNull);
  });

  testWidgets('hides active order time and shows delivered time', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 6, 15, 12, 43);
    final activeOrder = _order(
      status: CourierOrderStatus.assigned,
      expectedDeliveryAt: now,
    );
    final deliveredOrder = _order(
      status: CourierOrderStatus.delivered,
      expectedDeliveryAt: now,
      deliveredAt: now,
    );

    await tester.pumpWidget(
      _TestApp(
        child: OrderCard(order: activeOrder, onTap: () {}),
      ),
    );

    expect(find.text('الوصول'), findsNothing);
    expect(find.text('12:43'), findsNothing);
    expect(find.text('مطلوب الاستلام'), findsOneWidget);

    await tester.pumpWidget(
      _TestApp(
        child: OrderCard(
          order: deliveredOrder,
          showDeliveredMeta: true,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('وقت التسليم'), findsOneWidget);
    expect(find.text('12:43'), findsOneWidget);
  });

  test('parses authoritative courier statuses and safe legacy statuses', () {
    expect(courierOrderStatusFromRaw('assigned'), CourierOrderStatus.assigned);
    expect(CourierOrderStatus.assigned.label, 'مطلوب الاستلام');
    expect(courierOrderStatusFromRaw('ready'), CourierOrderStatus.assigned);
    expect(
      courierOrderStatusFromRaw('on_the_way'),
      CourierOrderStatus.pickedUp,
    );
    expect(
      courierOrderStatusFromRaw('under_preparation'),
      CourierOrderStatus.confirmed,
    );
  });

  test('courier lifecycle helpers expose the allowed courier actions', () {
    expect(CourierOrderStatus.assigned.requiresPickup, isTrue);
    expect(CourierOrderStatus.assigned.canMarkPickedUp, isTrue);
    expect(CourierOrderStatus.assigned.canMarkDelivered, isFalse);
    expect(CourierOrderStatus.pickedUp.canMarkPickedUp, isFalse);
    expect(CourierOrderStatus.pickedUp.canMarkDelivered, isTrue);

    final activeStatuses = CourierOrderStatus.values
        .where((status) => status.isActiveCourierOrder)
        .toList();
    expect(activeStatuses, [
      CourierOrderStatus.assigned,
      CourierOrderStatus.pickedUp,
    ]);
  });

  testWidgets('orders screen receives active orders without status filters', (
    WidgetTester tester,
  ) async {
    final now = DateTime(2026, 6, 15, 12, 43);

    await tester.pumpWidget(
      _TestApp(
        child: CourierOrdersView(
          orders: [
            _order(
              id: 'YM-1',
              status: CourierOrderStatus.assigned,
              expectedDeliveryAt: now,
            ),
            _order(
              id: 'YM-2',
              status: CourierOrderStatus.pickedUp,
              expectedDeliveryAt: now,
            ),
          ],
          onPickedUp: (orderId) async => _order(
            id: orderId,
            status: CourierOrderStatus.pickedUp,
            expectedDeliveryAt: now,
          ),
          onDelivered: (orderId, DeliveryConfirmationResult result) async =>
              _order(
                id: orderId,
                status: CourierOrderStatus.delivered,
                expectedDeliveryAt: now,
                deliveredAt: now,
              ),
          onRefresh: () async {},
        ),
      ),
    );

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('مطلوب الاستلام'), findsWidgets);
    expect(find.text('تم الاستلام'), findsWidgets);
  });

  testWidgets('profile stats navigate and theme can change inside app', (
    WidgetTester tester,
  ) async {
    AppThemeController.instance.setThemeMode(ThemeMode.system);
    var activeTapped = false;
    var deliveredTapped = false;

    await tester.pumpWidget(
      _TestApp(
        child: CourierProfileView(
          activeOrders: 3,
          deliveredOrders: 1,
          onActiveOrdersTap: () => activeTapped = true,
          onDeliveredSummaryTap: () => deliveredTapped = true,
          onLogout: () {},
        ),
      ),
    );

    await tester.tap(find.text('طلبات نشطة'));
    expect(activeTapped, isTrue);

    await tester.tap(find.text('إجمالي التسليم'));
    expect(deliveredTapped, isTrue);

    await tester.tap(find.text('ثيم التطبيق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('داكن').last);
    await tester.pump();
    expect(AppThemeController.instance.value, ThemeMode.dark);

    AppThemeController.instance.setThemeMode(ThemeMode.system);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );
  }
}

CourierOrder _order({
  String id = 'YM-1',
  required CourierOrderStatus status,
  required DateTime expectedDeliveryAt,
  DateTime? deliveredAt,
}) {
  return CourierOrder(
    id: id,
    customerName: 'أحمد مصطفى',
    phone: '+201001234567',
    address: 'شارع التحرير، الدقي',
    area: 'الدقي',
    total: 845,
    deliveryPrice: 45,
    status: status,
    rawStatus: switch (status) {
      CourierOrderStatus.assigned => 'assigned',
      CourierOrderStatus.pickedUp => 'picked_up',
      CourierOrderStatus.delivered => 'delivered',
      _ => status.name,
    },
    createdAt: expectedDeliveryAt.subtract(const Duration(hours: 1)),
    expectedDeliveryAt: expectedDeliveryAt,
    itemsCount: 1,
    marketName: 'محل تجريبي',
    marketBranch: 'فرع تجريبي',
    marketCount: 1,
    marketSummary: 'محل تجريبي',
    deliveredAt: deliveredAt,
    items: const [
      CourierOrderItem(name: 'منتج تجريبي', quantity: 1, price: 845),
    ],
  );
}
