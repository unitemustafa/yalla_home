import 'package:flutter/foundation.dart';

import '../../data/courier_notifications_api.dart';
import '../../domain/courier_notification.dart';

class CourierNotificationsController extends ChangeNotifier {
  CourierNotificationsController({
    CourierNotificationsApi api = const CourierNotificationsApi(),
  }) : _api = api;

  final CourierNotificationsApi _api;

  List<CourierNotification> _notifications = const [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isMarkingAllRead = false;
  String? _errorMessage;
  Future<void>? _loadInFlight;
  final Set<String> _deletingIds = <String>{};
  final Set<String> _readingIds = <String>{};

  List<CourierNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isMarkingAllRead => _isMarkingAllRead;
  String? get errorMessage => _errorMessage;

  bool isDeleting(CourierNotification notification) {
    return _deletingIds.contains(notification.id);
  }

  bool isReading(CourierNotification notification) {
    return _readingIds.contains(notification.id);
  }

  Future<void> loadNotifications() async {
    final activeLoad = _loadInFlight;
    if (activeLoad != null) return activeLoad;

    final loadFuture = _loadNotifications();
    _loadInFlight = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_loadInFlight, loadFuture)) {
        _loadInFlight = null;
      }
    }
  }

  Future<void> loadNotificationsIfNeeded() async {
    if (_hasLoaded) return;
    await loadNotifications();
  }

  Future<void> _loadNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loaded = await _api.loadNotifications();
      _notifications = loaded;
      _unreadCount = loaded
          .where((notification) => !notification.isRead)
          .length;
      try {
        _unreadCount = await _api.loadUnreadCount();
      } catch (_) {
        // The list is authoritative enough for rendering; the badge can retry.
      }
      _hasLoaded = true;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _arabicError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshNotifications() async {
    await loadNotifications();
  }

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _api.loadUnreadCount();
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  Future<CourierNotification> markRead(CourierNotification notification) async {
    if (notification.isRead) return notification;
    _readingIds.add(notification.id);
    notifyListeners();

    try {
      final updated = await _api.markRead(
        notification.id,
        current: notification,
      );
      _replaceNotification(updated);
      _unreadCount = _notifications.where((item) => !item.isRead).length;
      return updated;
    } finally {
      _readingIds.remove(notification.id);
      notifyListeners();
    }
  }

  Future<int> markAllRead() async {
    if (_isMarkingAllRead) return 0;
    _isMarkingAllRead = true;
    notifyListeners();

    try {
      final markedRead = await _api.markAllRead();
      _notifications = [
        for (final notification in _notifications)
          notification.copyWith(isRead: true, readAt: DateTime.now()),
      ];
      _unreadCount = 0;
      return markedRead;
    } finally {
      _isMarkingAllRead = false;
      notifyListeners();
    }
  }

  Future<void> deleteNotification(CourierNotification notification) async {
    _deletingIds.add(notification.id);
    notifyListeners();

    try {
      await _api.deleteNotification(notification.id);
      final wasUnread = !notification.isRead;
      _notifications = [
        for (final item in _notifications)
          if (item.id != notification.id) item,
      ];
      if (wasUnread && _unreadCount > 0) _unreadCount -= 1;
    } finally {
      _deletingIds.remove(notification.id);
      notifyListeners();
    }
  }

  void clear() {
    _notifications = const [];
    _unreadCount = 0;
    _isLoading = false;
    _hasLoaded = false;
    _isMarkingAllRead = false;
    _errorMessage = null;
    _loadInFlight = null;
    _deletingIds.clear();
    _readingIds.clear();
    notifyListeners();
  }

  void _replaceNotification(CourierNotification updated) {
    _notifications = [
      for (final notification in _notifications)
        if (notification.id == updated.id) updated else notification,
    ];
  }

  String _arabicError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return 'تعذر تحميل الإشعارات. حاول مرة أخرى.';
    }
    return message;
  }
}
