import '../../../core/auth/auth_session.dart';
import '../domain/courier_notification.dart';

class CourierNotificationsApi {
  const CourierNotificationsApi();

  Future<List<CourierNotification>> loadNotifications() async {
    final data = await AuthSession.instance.getJson('notifications/');
    return parseNotificationsResponse(data);
  }

  Future<int> loadUnreadCount() async {
    final data = await AuthSession.instance.getJson(
      'notifications/unread-count/',
    );
    return parseUnreadCountResponse(data);
  }

  Future<CourierNotification> markRead(
    String notificationId, {
    CourierNotification? current,
  }) async {
    final data = await AuthSession.instance.patchJson(
      'notifications/$notificationId/read/',
      const <String, dynamic>{},
    );
    if (data is Map) {
      return CourierNotification.fromJson(Map<String, dynamic>.from(data));
    }
    if (current != null) return current.copyWith(isRead: true);
    return CourierNotification(
      id: notificationId,
      audience: '',
      type: '',
      title: '',
      message: '',
      isRead: true,
      isBlocking: false,
      isResolved: false,
      createdAt: DateTime.now(),
    );
  }

  Future<int> markAllRead() async {
    final data = await AuthSession.instance.postJson(
      'notifications/mark-all-read/',
      const <String, dynamic>{},
    );
    if (data is Map) {
      return _int(data['marked_read'] ?? data['markedRead']);
    }
    return 0;
  }

  Future<void> deleteNotification(String notificationId) async {
    await AuthSession.instance.deleteJson('notifications/$notificationId/');
  }

  static List<CourierNotification> parseNotificationsResponse(dynamic data) {
    final rows = data is Map ? data['results'] : data;
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map(
          (item) =>
              CourierNotification.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((notification) => notification.id.isNotEmpty)
        .toList(growable: false);
  }

  static int parseUnreadCountResponse(dynamic data) {
    if (data is Map) {
      return _int(data['unread_count'] ?? data['unreadCount'] ?? data['count']);
    }
    return _int(data);
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
