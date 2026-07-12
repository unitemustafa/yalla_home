import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/notifications/courier_push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'foreground push is displayed and emitted once per notification id',
    () async {
      final service = CourierPushService.instance;
      var shown = 0;
      var emitted = 0;
      service.localShowOverrideForTesting = (_) async => shown++;
      final subscription = service.events.listen((_) => emitted++);
      final data = <String, dynamic>{
        'event': 'courier_order_assigned',
        'notification_id': 'push-test-1001',
        'order_id': '7',
        'order_number': '7',
      };

      await service.handleData(data, opened: false);
      await service.handleData(data, opened: false);
      await Future<void>.delayed(Duration.zero);

      expect(shown, 1);
      expect(emitted, 1);
      await subscription.cancel();
      service.localShowOverrideForTesting = null;
    },
  );

  test(
    'different notification ids for the same order remain distinct',
    () async {
      final service = CourierPushService.instance;
      var shown = 0;
      service.localShowOverrideForTesting = (_) async => shown++;

      await service.handleData({
        'event': 'courier_order_assigned',
        'notification_id': 'push-test-2001',
        'order_id': '8',
      }, opened: false);
      await service.handleData({
        'event': 'courier_order_unassigned',
        'notification_id': 'push-test-2002',
        'order_id': '8',
      }, opened: false);

      expect(shown, 2);
      service.localShowOverrideForTesting = null;
    },
  );
}
