import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:yalla_home/core/theme/app_theme_controller.dart';
import 'package:yalla_home/features/deliveries/data/courier_notifications_api.dart';
import 'package:yalla_home/features/deliveries/data/courier_orders_api.dart';
import 'package:yalla_home/features/deliveries/domain/courier_notification.dart';
import 'package:yalla_home/features/deliveries/domain/courier_order.dart';
import 'package:yalla_home/features/deliveries/presentation/controllers/courier_notifications_controller.dart';
import 'package:yalla_home/features/deliveries/presentation/views/courier_notifications_view.dart';
import 'package:yalla_home/features/deliveries/presentation/views/courier_orders_view.dart';
import 'package:yalla_home/features/deliveries/presentation/views/courier_profile_view.dart';
import 'package:yalla_home/features/deliveries/presentation/views/delivered_history_view.dart';
import 'package:yalla_home/features/deliveries/presentation/widgets/courier_notifications_button.dart';
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
    expect(find.text('15/06 12:43'), findsOneWidget);
  });

  testWidgets('delivered card shows fallback when delivered time is absent', (
    WidgetTester tester,
  ) async {
    final deliveredOrder = _order(
      status: CourierOrderStatus.delivered,
      expectedDeliveryAt: DateTime(2026, 6, 15, 12, 43),
    );

    await tester.pumpWidget(
      _TestApp(
        child: OrderCard(
          order: deliveredOrder,
          showDeliveredMeta: true,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('---'), findsOneWidget);
  });

  test('parses delivered_at before delivered history events', () {
    final order = CourierOrder.fromJson({
      'id': 'YM-1',
      'status': 'delivered',
      'created_at': '2026-06-15T09:00:00Z',
      'assigned_at': '2026-06-15T10:00:00Z',
      'delivered_at': '2026-06-15T12:43:00Z',
      'history': [
        {'to_status': 'delivered', 'created_at': '2026-06-15T11:30:00Z'},
      ],
    });

    expect(order.deliveredAt, DateTime.parse('2026-06-15T12:43:00Z').toLocal());
  });

  test('falls back to latest delivered history event only', () {
    final order = CourierOrder.fromJson({
      'id': 'YM-1',
      'status': 'delivered',
      'created_at': '2026-06-15T09:00:00Z',
      'assigned_at': '2026-06-15T10:00:00Z',
      'delivered_at': null,
      'history': [
        {'to_status': 'picked_up', 'created_at': '2026-06-15T10:30:00Z'},
        {'to_status': 'delivered', 'created_at': '2026-06-15T11:30:00Z'},
        {'to_status': 'delivered', 'created_at': '2026-06-15T12:43:00Z'},
      ],
    });

    expect(order.deliveredAt, DateTime.parse('2026-06-15T12:43:00Z').toLocal());
  });

  test('keeps deliveredAt null without an authoritative delivered time', () {
    final order = CourierOrder.fromJson({
      'id': 'YM-1',
      'status': 'delivered',
      'created_at': '2026-06-15T09:00:00Z',
      'assigned_at': '2026-06-15T10:00:00Z',
      'updated_at': '2026-06-15T12:43:00Z',
      'history': [
        {'to_status': 'picked_up', 'created_at': '2026-06-15T10:30:00Z'},
      ],
    });

    expect(order.deliveredAt, isNull);
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

    final pickedUpOrder = _order(
      status: CourierOrderStatus.assigned,
      expectedDeliveryAt: DateTime(2026, 6, 15, 12, 43),
    ).copyWith(status: CourierOrderStatus.pickedUp, rawStatus: 'picked_up');
    final deliveredOrder = pickedUpOrder.copyWith(
      status: CourierOrderStatus.delivered,
      rawStatus: 'delivered',
      deliveredAt: DateTime(2026, 6, 15, 13, 10),
      deliveryNote: 'تم التسليم للعميل',
    );

    expect(pickedUpOrder.canMarkDelivered, isTrue);
    expect(deliveredOrder.isDelivered, isTrue);
    expect(deliveredOrder.canMarkDelivered, isFalse);
    expect(deliveredOrder.deliveryNote, 'تم التسليم للعميل');
  });

  testWidgets(
    'delivery confirmation accepts optional notes and has no proof controls',
    (WidgetTester tester) async {
      DeliveryConfirmationResult? result;

      await tester.pumpWidget(
        _TestApp(
          child: DeliveryConfirmationSheetHost(
            onResult: (value) => result = value,
          ),
        ),
      );

      await tester.tap(find.text('فتح تأكيد التسليم'));
      await tester.pumpAndSettle();

      expect(find.text('كاميرا'), findsNothing);
      expect(find.text('المعرض'), findsNothing);
      expect(find.text('لا توجد صورة مرفوعة'), findsNothing);

      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result?.note, isNull);

      result = null;
      await tester.tap(find.text('فتح تأكيد التسليم'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'تم التسليم للعميل');
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();

      expect(result?.note, 'تم التسليم للعميل');
    },
  );

  test('delivery confirmation API uses JSON status update without proof', () {
    final source = File(
      'lib/features/deliveries/data/courier_orders_api.dart',
    ).readAsStringSync();

    expect(source, contains('patchJson'));
    expect(source, contains("'status': 'delivered'"));
    expect(source, contains("'delivery_note': deliveryNote"));
    expect(
      source,
      contains('if (deliveryNote != null && deliveryNote.isNotEmpty)'),
    );
    expect(source, isNot(contains('DeliveryProof')));
    expect(source, isNot(contains('patchMultipart')));
    expect(source, isNot(contains('deliveryProof')));
  });

  test(
    'order details exposes enabled contact and disabled map action only',
    () {
      final source = File(
        'lib/features/deliveries/presentation/views/order_details_view.dart',
      ).readAsStringSync();

      expect(source, contains("label: const Text('تواصل')"));
      expect(source, contains('onPressed: () => _showContactOptions(context)'));
      expect(source, contains('onPressed: null'));
      expect(source, contains("label: const Text('الخريطة')"));
      expect(source, isNot(contains('_openMap')));
      expect(source, isNot(contains('CourierTrackingMapView')));
      expect(source, isNot(contains('courier_tracking_map_view.dart')));
    },
  );

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
          unreadNotificationCount: 2,
          onNotificationsPressed: () {},
        ),
      ),
    );

    expect(find.byTooltip('الإشعارات'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('مطلوب الاستلام'), findsWidgets);
    expect(find.text('تم الاستلام'), findsWidgets);
  });

  testWidgets('delivered header shows bell and requested subtitle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: DeliveredHistoryView(
          orders: [
            _order(
              status: CourierOrderStatus.delivered,
              expectedDeliveryAt: DateTime(2026, 6, 15, 12, 43),
              deliveredAt: DateTime(2026, 6, 15, 12, 43),
            ),
          ],
          unreadNotificationCount: 3,
          onNotificationsPressed: () {},
        ),
      ),
    );

    expect(find.byTooltip('الإشعارات'), findsOneWidget);
    expect(find.text('الطلبات المسلّمة'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('notification badge shows count and hides at zero', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsButton(unreadCount: 5, onPressed: () {}),
      ),
    );

    expect(find.text('5'), findsOneWidget);

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsButton(unreadCount: 0, onPressed: () {}),
      ),
    );

    expect(find.text('5'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  test('parses real notification responses safely', () {
    final raw = {
      'id': 91,
      'audience': 'courier',
      'type': 'order_assigned',
      'title': 'New order assigned',
      'message': 'A new order #123 has been assigned to you.',
      'order_id': 123,
      'is_read': false,
      'is_blocking': false,
      'is_resolved': false,
      'read_at': null,
      'resolved_at': null,
      'created_at': '2026-07-08T09:15:00Z',
    };

    final notification = CourierNotification.fromJson(raw);

    expect(notification.id, '91');
    expect(notification.orderId, '123');
    expect(notification.hasLinkedOrder, isTrue);
    expect(notification.isRead, isFalse);
    expect(notification.displayTitle, 'تم إسناد طلب جديد');
    expect(notification.displayMessage, 'تم إسناد الطلب #123 إليك.');
    expect(
      notification.createdAt,
      DateTime.parse('2026-07-08T09:15:00Z').toLocal(),
    );
  });

  test('parses raw-list and paginated notification responses', () {
    final raw = [
      _notificationJson(id: 1, orderId: 101),
      _notificationJson(id: 2, orderId: null, isRead: true),
    ];
    final paginated = {'count': 2, 'results': raw};

    expect(
      CourierNotificationsApi.parseNotificationsResponse(raw),
      hasLength(2),
    );
    expect(
      CourierNotificationsApi.parseNotificationsResponse(
        paginated,
      ).map((notification) => notification.id),
      ['1', '2'],
    );
  });

  test('parses backend unread count response', () {
    expect(
      CourierNotificationsApi.parseUnreadCountResponse({'unread_count': 7}),
      7,
    );
    expect(CourierNotificationsApi.parseUnreadCountResponse('4'), 4);
  });

  test(
    'controller updates unread badge only after mark-read success',
    () async {
      final api = _FakeNotificationsApi(
        notifications: [_notification(id: '1', orderId: '123')],
        unreadCount: 1,
      );
      final controller = CourierNotificationsController(api: api);
      await controller.loadNotifications();

      expect(controller.unreadCount, 1);
      await controller.markRead(controller.notifications.single);

      expect(api.markReadCalls, ['1']);
      expect(controller.notifications.single.isRead, isTrue);
      expect(controller.unreadCount, 0);
    },
  );

  test('mark-all-read failure preserves unread state', () async {
    final api = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    )..markAllError = Exception('backend failed');
    final controller = CourierNotificationsController(api: api);
    await controller.loadNotifications();

    expect(controller.markAllRead(), throwsException);
    expect(controller.notifications.single.isRead, isFalse);
    expect(controller.unreadCount, 1);
  });

  test(
    'controller clear prevents cross-courier notification leakage',
    () async {
      final controller = CourierNotificationsController(
        api: _FakeNotificationsApi(
          notifications: [_notification(id: '1', orderId: '123')],
          unreadCount: 1,
        ),
      );
      await controller.loadNotifications();

      controller.clear();

      expect(controller.notifications, isEmpty);
      expect(controller.unreadCount, 0);
      expect(controller.errorMessage, isNull);
    },
  );

  testWidgets('notifications view shows loading, error, and retry', (
    WidgetTester tester,
  ) async {
    final failedLoad = Completer<List<CourierNotification>>();
    final successfulLoad = Completer<List<CourierNotification>>();
    final api = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    )..loadCompleter = failedLoad;
    final controller = CourierNotificationsController(api: api);

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: controller,
          ordersApi: _FakeOrdersApi(),
          onOrderTap: (_) {},
          onUnreadCountChanged: (_) {},
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    failedLoad.completeError(Exception('network failed'));
    await tester.pump();
    expect(find.text('تعذر تحميل الإشعارات'), findsOneWidget);

    api.loadCompleter = successfulLoad;
    await tester.tap(find.byKey(const Key('courier_notifications_retry')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    successfulLoad.complete(api.notifications);
    await tester.pump();

    expect(find.text('تم إسناد طلب جديد'), findsOneWidget);
  });

  testWidgets('unread cards mark read before opening details', (
    WidgetTester tester,
  ) async {
    final api = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    );

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: CourierNotificationsController(api: api),
          ordersApi: _FakeOrdersApi(),
          onOrderTap: (_) {},
          onUnreadCountChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('تم إسناد طلب جديد'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('courier_notification_1')));
    await tester.pumpAndSettle();

    expect(api.markReadCalls, ['1']);
    expect(find.text('تفاصيل الإشعار'), findsOneWidget);
  });

  testWidgets('mark-all-read updates loaded records and badge after success', (
    WidgetTester tester,
  ) async {
    var unread = -1;
    final api = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    );

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: CourierNotificationsController(api: api),
          ordersApi: _FakeOrdersApi(),
          onOrderTap: (_) {},
          onUnreadCountChanged: (count) => unread = count,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('courier_notifications_mark_all')));
    await tester.pump();

    expect(api.markAllCalls, 1);
    expect(unread, 0);
    expect(find.text('كل الإشعارات مقروءة'), findsOneWidget);
  });

  testWidgets('failed delete keeps the notification card visible', (
    WidgetTester tester,
  ) async {
    final api = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    )..deleteError = Exception('delete failed');

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: CourierNotificationsController(api: api),
          ordersApi: _FakeOrdersApi(),
          onOrderTap: (_) {},
          onUnreadCountChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('courier_notification_1')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    expect(api.deleteCalls, ['1']);
    expect(find.text('تم إسناد طلب جديد'), findsOneWidget);
  });

  testWidgets('opening linked order loads the real courier order', (
    WidgetTester tester,
  ) async {
    CourierOrder? opened;
    final notificationsApi = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    );
    final ordersApi = _FakeOrdersApi(
      orders: {
        '123': _order(
          id: '123',
          status: CourierOrderStatus.assigned,
          expectedDeliveryAt: DateTime(2026, 7, 8, 10),
        ),
      },
    );

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: CourierNotificationsController(api: notificationsApi),
          ordersApi: ordersApi,
          onOrderTap: (order) => opened = order,
          onUnreadCountChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('courier_notification_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح الطلب'));
    await tester.pumpAndSettle();

    expect(ordersApi.loadOrderCalls, ['123']);
    expect(opened?.id, '123');
  });

  testWidgets('missing linked order shows an error and does not crash', (
    WidgetTester tester,
  ) async {
    final notificationsApi = _FakeNotificationsApi(
      notifications: [_notification(id: '1', orderId: '123')],
      unreadCount: 1,
    );
    final ordersApi = _FakeOrdersApi()..loadError = Exception('404');

    await tester.pumpWidget(
      _TestApp(
        child: CourierNotificationsView(
          controller: CourierNotificationsController(api: notificationsApi),
          ordersApi: ordersApi,
          onOrderTap: (_) => fail('should not open unavailable order'),
          onUnreadCountChanged: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('courier_notification_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح الطلب'));
    await tester.pumpAndSettle();

    expect(ordersApi.loadOrderCalls, ['123']);
    expect(find.text('هذا الطلب لم يعد متاحا لك.'), findsOneWidget);
  });

  test('no runtime code generates notifications from CourierOrder', () {
    final source = File(
      'lib/features/deliveries/presentation/views/courier_notifications_view.dart',
    ).readAsStringSync();
    final controllerSource = File(
      'lib/features/deliveries/presentation/controllers/courier_notifications_controller.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('fromOrder')));
    expect(source, isNot(contains('assigned-')));
    expect(source, isNot(contains('delivered-')));
    expect(source, isNot(contains('expectedDeliveryAt')));
    expect(controllerSource, isNot(contains('_readIds')));
    expect(controllerSource, isNot(contains('_dismissedIds')));
  });

  testWidgets('tapping header bell opens notifications and back returns', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: const _OrdersNotificationsRouteHost(),
        ),
      ),
    );

    expect(find.text('طلبات التوصيل'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selected-bottom-orders')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('الإشعارات'));
    await tester.pumpAndSettle();

    final backButton = find.byKey(
      const Key('courier_notifications_back_button'),
    );
    expect(find.text('الإشعارات'), findsOneWidget);
    expect(find.byType(CourierNotificationsView), findsOneWidget);
    expect(backButton, findsOneWidget);
    final backIcon = tester.widget<Icon>(
      find.descendant(of: backButton, matching: find.byType(Icon)),
    );
    expect(backIcon.icon?.codePoint, 0xe936);
    expect(backIcon.icon?.fontFamily, 'iconsax');
    expect(backIcon.size, 21);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.byType(CourierNotificationsView), findsNothing);
    expect(find.text('طلبات التوصيل'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selected-bottom-orders')),
      findsOneWidget,
    );
  });

  testWidgets(
    'notifications header back button and mark-all survive narrow width',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var unreadCount = -1;

      await tester.pumpWidget(
        _TestApp(
          child: CourierNotificationsView(
            controller: CourierNotificationsController(
              api: _FakeNotificationsApi(
                notifications: [_notification(id: '1', orderId: '123')],
                unreadCount: 1,
              ),
            ),
            ordersApi: _FakeOrdersApi(),
            onOrderTap: (_) {},
            onUnreadCountChanged: (count) => unreadCount = count,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final backButton = find.byKey(
        const Key('courier_notifications_back_button'),
      );
      expect(tester.takeException(), isNull);
      expect(backButton, findsOneWidget);
      expect(
        find.byKey(const Key('courier_notifications_mark_all')),
        findsOneWidget,
      );
      expect(unreadCount, 1);

      await tester.tap(find.byKey(const Key('courier_notifications_mark_all')));
      await tester.pump();

      expect(unreadCount, 0);
    },
  );

  test('bottom navigation source has exactly Orders, Delivered, Account', () {
    final source = File(
      'lib/features/deliveries/presentation/views/courier_shell_view.dart',
    ).readAsStringSync();

    expect(source, contains('List.generate(_items.length'));
    expect(source, isNot(contains('notificationBadgeCount')));
    expect(source, isNot(contains('notification_bing')));
    expect(
      RegExp(r'^\s+_NavigationItemData\(', multiLine: true).allMatches(source),
      hasLength(3),
    );
  });

  test('historical delivery proof display support remains intact', () {
    final source = File(
      'lib/features/deliveries/presentation/views/order_details_view.dart',
    ).readAsStringSync();

    expect(source, contains('order.deliveryProof'));
    expect(source, contains('order.deliveryProofUrl'));
    expect(source, contains('Image.network'));
    expect(source, contains('Image.memory'));
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

class DeliveryConfirmationSheetHost extends StatelessWidget {
  const DeliveryConfirmationSheetHost({super.key, required this.onResult});

  final ValueChanged<DeliveryConfirmationResult> onResult;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          final result = await showModalBottomSheet<DeliveryConfirmationResult>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const DeliveryConfirmationSheet(orderId: 'YM-1'),
          );
          if (result != null) onResult(result);
        },
        child: const Text('فتح تأكيد التسليم'),
      ),
    );
  }
}

class _OrdersNotificationsRouteHost extends StatelessWidget {
  const _OrdersNotificationsRouteHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourierOrdersView(
        orders: const [],
        onPickedUp: (orderId) async => _order(
          id: orderId,
          status: CourierOrderStatus.pickedUp,
          expectedDeliveryAt: DateTime(2026, 6, 15, 12, 43),
        ),
        onDelivered: (orderId, result) async => _order(
          id: orderId,
          status: CourierOrderStatus.delivered,
          expectedDeliveryAt: DateTime(2026, 6, 15, 12, 43),
        ),
        onRefresh: () async {},
        unreadNotificationCount: 1,
        onNotificationsPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => Directionality(
                textDirection: TextDirection.rtl,
                child: CourierNotificationsView(
                  controller: CourierNotificationsController(
                    api: _FakeNotificationsApi(),
                  ),
                  ordersApi: _FakeOrdersApi(),
                  onOrderTap: (_) {},
                  onUnreadCountChanged: (_) {},
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: Text('الطلبات', key: ValueKey('selected-bottom-orders')),
            ),
            Expanded(child: Text('المسلّمة')),
            Expanded(child: Text('حسابي')),
          ],
        ),
      ),
    );
  }
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

class _FakeNotificationsApi extends CourierNotificationsApi {
  _FakeNotificationsApi({
    List<CourierNotification>? notifications,
    this.unreadCount = 0,
  }) : notifications = notifications ?? const [];

  List<CourierNotification> notifications;
  int unreadCount;
  Object? loadError;
  Completer<List<CourierNotification>>? loadCompleter;
  Object? markReadError;
  Object? markAllError;
  Object? deleteError;
  int loadCalls = 0;
  int markAllCalls = 0;
  final List<String> markReadCalls = [];
  final List<String> deleteCalls = [];

  @override
  Future<List<CourierNotification>> loadNotifications() async {
    loadCalls += 1;
    final completer = loadCompleter;
    if (completer != null) {
      loadCompleter = null;
      return completer.future;
    }
    if (loadError != null) throw loadError!;
    return notifications;
  }

  @override
  Future<int> loadUnreadCount() async {
    if (loadError != null) throw loadError!;
    return unreadCount;
  }

  @override
  Future<CourierNotification> markRead(
    String notificationId, {
    CourierNotification? current,
  }) async {
    markReadCalls.add(notificationId);
    if (markReadError != null) throw markReadError!;
    final updated =
        (current ??
                notifications.firstWhere(
                  (notification) => notification.id == notificationId,
                ))
            .copyWith(isRead: true, readAt: DateTime.now());
    notifications = [
      for (final notification in notifications)
        if (notification.id == notificationId) updated else notification,
    ];
    unreadCount = notifications
        .where((notification) => !notification.isRead)
        .length;
    return updated;
  }

  @override
  Future<int> markAllRead() async {
    markAllCalls += 1;
    if (markAllError != null) throw markAllError!;
    final previousUnread = unreadCount;
    notifications = [
      for (final notification in notifications)
        notification.copyWith(isRead: true, readAt: DateTime.now()),
    ];
    unreadCount = 0;
    return previousUnread;
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    deleteCalls.add(notificationId);
    if (deleteError != null) throw deleteError!;
    final removed = notifications
        .where((notification) => notification.id == notificationId)
        .toList();
    notifications = [
      for (final notification in notifications)
        if (notification.id != notificationId) notification,
    ];
    if (removed.any((notification) => !notification.isRead) &&
        unreadCount > 0) {
      unreadCount -= 1;
    }
  }
}

class _FakeOrdersApi extends CourierOrdersApi {
  _FakeOrdersApi({Map<String, CourierOrder>? orders}) : orders = orders ?? {};

  final Map<String, CourierOrder> orders;
  final List<String> loadOrderCalls = [];
  Object? loadError;

  @override
  Future<CourierOrder> loadOrder(String orderId) async {
    loadOrderCalls.add(orderId);
    if (loadError != null) throw loadError!;
    final order = orders[orderId];
    if (order == null) throw Exception('not found');
    return order;
  }
}

CourierNotification _notification({
  required String id,
  String? orderId,
  bool isRead = false,
}) {
  return CourierNotification.fromJson(
    _notificationJson(id: int.parse(id), orderId: orderId, isRead: isRead),
  );
}

Map<String, dynamic> _notificationJson({
  required int id,
  Object? orderId = 123,
  bool isRead = false,
}) {
  return {
    'id': id,
    'audience': 'courier',
    'type': 'order_assigned',
    'title': 'New order assigned',
    'message': 'A new order has been assigned to you.',
    'order_id': orderId,
    'is_read': isRead,
    'is_blocking': false,
    'is_resolved': false,
    'read_at': null,
    'resolved_at': null,
    'created_at': '2026-07-08T09:15:00Z',
  };
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
