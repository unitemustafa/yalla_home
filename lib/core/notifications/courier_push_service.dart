import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../auth/auth_session.dart';
import '../routing/app_navigator.dart';

const courierOrdersChannelId = 'courier_orders';
const accountUpdatesChannelId = 'account_updates';
const courierUpdatesChannelId = 'courier_updates';

@pragma('vm:entry-point')
Future<void> courierFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class CourierPushEvent {
  const CourierPushEvent(this.data, {required this.opened});
  final Map<String, dynamic> data;
  final bool opened;
  String get event => data['event']?.toString() ?? '';

  String get title {
    final remoteTitle = data['_title']?.toString().trim() ?? '';
    if (remoteTitle.isNotEmpty) return remoteTitle;
    return switch (event) {
      'courier_order_assigned' => 'طلب توصيل جديد',
      'courier_order_unassigned' => 'تم سحب طلب',
      'courier_order_cancelled' => 'تم إلغاء طلب',
      'courier_account_restored' => 'تم استعادة حسابك',
      'courier_profile_updated' => 'تم تحديث بيانات حسابك',
      'courier_availability_changed' => 'تحديث حالة استقبال الطلبات',
      _ => 'تحديث من يلا ماركت',
    };
  }

  String get body {
    final remoteBody = data['_body']?.toString().trim() ?? '';
    if (remoteBody.isNotEmpty) return remoteBody;
    final number = data['order_number'] ?? data['order_id'] ?? '';
    return switch (event) {
      'courier_order_assigned' =>
        'تم تعيين الطلب #$number لك. اضغط لعرض التفاصيل.',
      'courier_order_unassigned' => 'تم سحب الطلب #$number من قائمة مهامك.',
      'courier_order_cancelled' => 'تم إلغاء الطلب #$number.',
      'courier_account_restored' =>
        'تم استعادة حساب المندوب بواسطة فريق دعم يلا ماركت.',
      'courier_profile_updated' => 'تم تحديث بيانات المندوب.',
      'courier_availability_changed' => 'تم تحديث حالة استقبال الطلبات.',
      _ => 'تم تحديث بيانات حساب المندوب.',
    };
  }
}

class CourierPushService {
  CourierPushService._();
  static final instance = CourierPushService._();

  final _local = FlutterLocalNotificationsPlugin();
  final _events = StreamController<CourierPushEvent>.broadcast();
  final List<CourierPushEvent> _pendingOpenedEvents = [];
  final Map<String, DateTime> _handled = {};
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  bool _initialized = false;
  bool _disablingAccount = false;
  Future<void> Function(Map<String, dynamic>)? _localShowOverride;

  Stream<CourierPushEvent> get events => _events.stream;

  @visibleForTesting
  set localShowOverrideForTesting(
    Future<void> Function(Map<String, dynamic>)? callback,
  ) => _localShowOverride = callback;

  List<CourierPushEvent> takePendingOpenedEvents() {
    final pending = List<CourierPushEvent>.from(_pendingOpenedEvents);
    _pendingOpenedEvents.clear();
    return pending;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      FirebaseMessaging.onBackgroundMessage(courierFirebaseBackgroundHandler);
      await Firebase.initializeApp();
      await _initializeLocalNotifications();
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        (message) => unawaited(_handle(message, opened: false)),
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => unawaited(_handle(message, opened: true)),
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => unawaited(_registerToken(token)),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) await _handle(initial, opened: true);
    } catch (error, stackTrace) {
      _debugFailure('initialization', error, stackTrace);
    }
  }

  Future<void> registerAuthenticatedDevice() async {
    if (AuthSession.instance.currentUser?['role'] != 'representative') return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (error, stackTrace) {
      _debugFailure('device registration', error, stackTrace);
    }
  }

  Future<void> _registerToken(String token) async {
    if (AuthSession.instance.currentUser?['role'] != 'representative') return;
    try {
      await AuthSession.instance.postJson('notifications/devices/register/', {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      });
    } catch (error, stackTrace) {
      _debugFailure('token registration', error, stackTrace);
    }
  }

  Future<void> _initializeLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          unawaited(
            handleData(Map<String, dynamic>.from(decoded), opened: true),
          );
        }
      },
    );
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        courierOrdersChannelId,
        'طلبات التوصيل',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        accountUpdatesChannelId,
        'تحديثات الحساب',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        courierUpdatesChannelId,
        'تحديثات المندوب',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  Future<void> _handle(RemoteMessage message, {required bool opened}) async {
    final data = Map<String, dynamic>.from(message.data);
    if (message.messageId != null) data['_message_id'] = message.messageId!;
    data['_title'] = message.notification?.title;
    data['_body'] = message.notification?.body;
    await handleData(data, opened: opened);
  }

  @visibleForTesting
  Future<void> handleData(
    Map<String, dynamic> data, {
    required bool opened,
  }) async {
    final event = data['event']?.toString() ?? '';
    if (event.isEmpty || !_accept(data, opened: opened)) return;
    if (event == 'courier_account_disabled') {
      await _disableAccountOnce();
      return;
    }
    if (!opened && event != 'courier_profile_updated') {
      await _showLocal(data);
    }
    if (opened) await _handleTap(data);
    final pushEvent = CourierPushEvent(data, opened: opened);
    if (opened && !_events.hasListener) {
      _pendingOpenedEvents.add(pushEvent);
    } else {
      _events.add(pushEvent);
    }
  }

  bool _accept(Map<String, dynamic> data, {required bool opened}) {
    final now = DateTime.now();
    _handled.removeWhere(
      (_, at) => now.difference(at) > const Duration(minutes: 10),
    );
    while (_handled.length >= 100) {
      _handled.remove(_handled.keys.first);
    }
    final notificationId = data['notification_id']?.toString().trim();
    final phase = opened ? 'open' : 'display';
    final key = notificationId != null && notificationId.isNotEmpty
        ? '$phase:notification:$notificationId'
        : '$phase:${data['event']}:${data['order_id'] ?? ''}:${data['_message_id'] ?? ''}';
    return _handled.putIfAbsent(key, () => now) == now;
  }

  Future<void> _showLocal(Map<String, dynamic> data) async {
    final override = _localShowOverride;
    if (override != null) {
      await override(data);
      return;
    }
    final event = data['event']?.toString() ?? '';
    final channel = event.startsWith('courier_order_')
        ? courierOrdersChannelId
        : event.startsWith('courier_account_')
        ? accountUpdatesChannelId
        : courierUpdatesChannelId;
    final channelName = channel == courierOrdersChannelId
        ? 'طلبات التوصيل'
        : channel == accountUpdatesChannelId
        ? 'تحديثات الحساب'
        : 'تحديثات المندوب';
    final pushEvent = CourierPushEvent(data, opened: false);
    final title = pushEvent.title;
    final body = pushEvent.body;
    await _local.show(
      id:
          int.tryParse(data['notification_id']?.toString() ?? '') ??
          data.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channelName,
          importance: channel == courierUpdatesChannelId
              ? Importance.defaultImportance
              : Importance.high,
          priority: channel == courierUpdatesChannelId
              ? Priority.defaultPriority
              : Priority.high,
          icon: 'ic_notification',
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  Future<void> _handleTap(Map<String, dynamic> data) async {
    final event = data['event']?.toString();
    if (event == 'courier_account_restored') {
      AppNavigator.goToLogin();
      return;
    }
    if (AuthSession.instance.currentUser == null) {
      AppNavigator.goToLogin();
    }
  }

  Future<void> _disableAccountOnce() async {
    if (_disablingAccount) return;
    _disablingAccount = true;
    await AuthSession.instance.clear();
    AppNavigator.goToLogin();
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _events.close();
  }
}

void _debugFailure(String operation, Object error, StackTrace stackTrace) {
  if (!kDebugMode) return;
  debugPrint('Courier push $operation failed (${error.runtimeType}).');
}
