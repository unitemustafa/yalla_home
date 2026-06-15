import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yalla_home/core/theme/app_theme_controller.dart';
import 'package:yalla_home/features/deliveries/domain/courier_order.dart';
import 'package:yalla_home/features/deliveries/presentation/views/courier_profile_view.dart';
import 'package:yalla_home/features/deliveries/presentation/widgets/order_card.dart';
import 'package:yalla_home/yalla_home_app.dart';

void main() {
  testWidgets('shows Yalla Home login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const YallaHomeApp());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('أهلاً يا كابتن'), findsOneWidget);
    expect(find.text('رقم الموبايل أو الإيميل'), findsOneWidget);
    expect(find.text('دخول Demo'), findsNothing);
    expect(find.text('تذكرني'), findsOneWidget);
    expect(find.text('تواصل مع الدعم'), findsOneWidget);

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.elementAt(0).controller?.text, 'yalla@admin.com');
    expect(fields.elementAt(1).controller?.text, '01266666610');

    final rememberMe = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(rememberMe.value, isTrue);

    final supportButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'تواصل مع الدعم'),
    );
    expect(supportButton.onPressed, isNull);
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
  required CourierOrderStatus status,
  required DateTime expectedDeliveryAt,
  DateTime? deliveredAt,
}) {
  return CourierOrder(
    id: 'YM-1',
    customerName: 'أحمد مصطفى',
    phone: '+201001234567',
    address: 'شارع التحرير، الدقي',
    area: 'الدقي',
    total: 845,
    status: status,
    createdAt: expectedDeliveryAt.subtract(const Duration(hours: 1)),
    expectedDeliveryAt: expectedDeliveryAt,
    deliveredAt: deliveredAt,
    items: const [
      CourierOrderItem(name: 'منتج تجريبي', quantity: 1, price: 845),
    ],
  );
}
