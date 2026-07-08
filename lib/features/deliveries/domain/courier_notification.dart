class CourierNotification {
  const CourierNotification({
    required this.id,
    required this.audience,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.isBlocking,
    required this.isResolved,
    required this.createdAt,
    this.orderId,
    this.readAt,
    this.resolvedAt,
  });

  factory CourierNotification.fromJson(Map<String, dynamic> json) {
    return CourierNotification(
      id: _string(json['id'], fallback: ''),
      audience: _string(json['audience'], fallback: ''),
      type: _string(json['type'], fallback: ''),
      title: _string(json['title'], fallback: ''),
      message: _string(json['message'], fallback: ''),
      orderId: _optionalString(json['order_id'] ?? json['orderId']),
      isRead: _bool(json['is_read'] ?? json['isRead']),
      isBlocking: _bool(json['is_blocking'] ?? json['isBlocking']),
      isResolved: _bool(json['is_resolved'] ?? json['isResolved']),
      readAt: _optionalDate(json['read_at'] ?? json['readAt']),
      resolvedAt: _optionalDate(json['resolved_at'] ?? json['resolvedAt']),
      createdAt:
          _optionalDate(json['created_at'] ?? json['createdAt']) ??
          DateTime.now(),
    );
  }

  final String id;
  final String audience;
  final String type;
  final String title;
  final String message;
  final String? orderId;
  final bool isRead;
  final bool isBlocking;
  final bool isResolved;
  final DateTime? readAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  bool get hasLinkedOrder => orderId != null && orderId!.isNotEmpty;

  String get displayTitle {
    if (type == 'order_assigned') return 'تم إسناد طلب جديد';
    return title.isNotEmpty ? title : 'إشعار';
  }

  String get displayMessage {
    if (type == 'order_assigned') {
      final order = orderId;
      if (order != null && order.isNotEmpty) {
        return 'تم إسناد الطلب #$order إليك.';
      }
      return 'تم إسناد طلب جديد إليك.';
    }
    return message.isNotEmpty ? message : 'لديك إشعار جديد.';
  }

  String relativeTimeLabel({DateTime? now}) {
    final reference = now ?? DateTime.now();
    var difference = reference.difference(createdAt);
    if (difference.isNegative) {
      difference = difference.abs() <= const Duration(minutes: 2)
          ? Duration.zero
          : Duration.zero;
    }
    if (difference.inMinutes < 1) return 'الآن';
    if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    }
    if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة';
    return 'منذ ${difference.inDays} يوم';
  }

  CourierNotification copyWith({
    String? id,
    String? audience,
    String? type,
    String? title,
    String? message,
    String? orderId,
    bool? isRead,
    bool? isBlocking,
    bool? isResolved,
    DateTime? readAt,
    DateTime? resolvedAt,
    DateTime? createdAt,
  }) {
    return CourierNotification(
      id: id ?? this.id,
      audience: audience ?? this.audience,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      orderId: orderId ?? this.orderId,
      isRead: isRead ?? this.isRead,
      isBlocking: isBlocking ?? this.isBlocking,
      isResolved: isResolved ?? this.isResolved,
      readAt: readAt ?? this.readAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String _string(Object? value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? null : text;
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'y';
  }

  static DateTime? _optionalDate(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.toLocal();
  }
}
