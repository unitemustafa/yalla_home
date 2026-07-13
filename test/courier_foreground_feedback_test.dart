import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_home/core/notifications/courier_push_service.dart';
import 'package:yalla_home/yalla_home_app.dart';

void main() {
  test('foreground courier push invokes the global banner once', () async {
    var shown = 0;
    final event = CourierPushEvent(const {
      'event': 'courier_order_assigned',
      'notification_id': 'feedback-1',
      'order_id': '42',
    }, opened: false);

    final displayed = await presentCourierForegroundFeedback(
      event,
      showBanner: (_) async => shown++,
    );

    expect(displayed, isTrue);
    expect(shown, 1);
    expect(event.title, 'طلب توصيل جديد');
    expect(event.body, contains('#42'));
  });

  test('opened courier push does not duplicate the global banner', () async {
    var shown = 0;
    final displayed = await presentCourierForegroundFeedback(
      const CourierPushEvent({
        'event': 'courier_order_assigned',
        'notification_id': 'feedback-2',
      }, opened: true),
      showBanner: (_) async => shown++,
    );

    expect(displayed, isFalse);
    expect(shown, 0);
  });
}
