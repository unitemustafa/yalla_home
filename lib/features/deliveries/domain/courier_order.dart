import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/constants/app_colors.dart';

enum CourierOrderStatus {
  pending,
  confirmed,
  assigned,
  pickedUp,
  delivered,
  failedDelivery,
  cancelled,
  unknown,
}

extension CourierOrderStatusLabel on CourierOrderStatus {
  String get label {
    return switch (this) {
      CourierOrderStatus.pending => 'قيد الانتظار',
      CourierOrderStatus.confirmed => 'مؤكد',
      CourierOrderStatus.assigned => 'مطلوب الاستلام',
      CourierOrderStatus.pickedUp => 'تم الاستلام',
      CourierOrderStatus.delivered => 'تم التسليم',
      CourierOrderStatus.failedDelivery => 'تعذر التوصيل',
      CourierOrderStatus.cancelled => 'ملغي',
      CourierOrderStatus.unknown => 'حالة غير معروفة',
    };
  }

  Color get color {
    return switch (this) {
      CourierOrderStatus.pending => AppColors.warning,
      CourierOrderStatus.confirmed => AppColors.info,
      CourierOrderStatus.assigned => AppColors.info,
      CourierOrderStatus.pickedUp => AppColors.primary,
      CourierOrderStatus.delivered => AppColors.success,
      CourierOrderStatus.failedDelivery => AppColors.error,
      CourierOrderStatus.cancelled => AppColors.error,
      CourierOrderStatus.unknown => AppColors.lightTextSecondary,
    };
  }

  bool get isTerminal {
    return switch (this) {
      CourierOrderStatus.delivered ||
      CourierOrderStatus.failedDelivery ||
      CourierOrderStatus.cancelled => true,
      _ => false,
    };
  }

  bool get isActiveCourierOrder {
    return this == CourierOrderStatus.assigned ||
        this == CourierOrderStatus.pickedUp;
  }

  bool get requiresPickup => this == CourierOrderStatus.assigned;

  bool get canMarkPickedUp => this == CourierOrderStatus.assigned;

  bool get canMarkDelivered => this == CourierOrderStatus.pickedUp;

  bool get isDelivered => this == CourierOrderStatus.delivered;
}

CourierOrderStatus courierOrderStatusFromRaw(Object? value) {
  return switch (value?.toString().trim().toLowerCase()) {
    'pending' => CourierOrderStatus.pending,
    'confirmed' => CourierOrderStatus.confirmed,
    'assigned' => CourierOrderStatus.assigned,
    'under_preparation' || 'preparing' => CourierOrderStatus.confirmed,
    'ready' => CourierOrderStatus.assigned,
    'picked_up' => CourierOrderStatus.pickedUp,
    'on_the_way' => CourierOrderStatus.pickedUp,
    'delivered' || 'completed' => CourierOrderStatus.delivered,
    'failed_delivery' => CourierOrderStatus.failedDelivery,
    'cancelled' || 'canceled' || 'rejected' => CourierOrderStatus.cancelled,
    _ => CourierOrderStatus.unknown,
  };
}

class DeliveryProof {
  const DeliveryProof({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class OrderLocation {
  const OrderLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class CourierOrderItem {
  const CourierOrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.subtotal,
  });

  final String name;
  final int quantity;
  final double price;
  final double? subtotal;

  double get total => subtotal ?? price * quantity;
}

class CourierOrder {
  const CourierOrder({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.area,
    required this.total,
    required this.deliveryPrice,
    required this.status,
    required this.rawStatus,
    required this.createdAt,
    required this.expectedDeliveryAt,
    required this.items,
    required this.itemsCount,
    required this.marketName,
    required this.marketBranch,
    required this.marketCount,
    required this.marketSummary,
    this.addressLabel,
    this.serviceCityName,
    this.deliveryAreaName,
    this.customerAvatarUrl,
    this.mapQuery,
    this.customerLocation,
    this.customerNotes,
    this.deliveredAt,
    this.deliveryNote,
    this.deliveryProof,
    this.deliveryProofUrl,
  });

  final String id;
  final String customerName;
  final String phone;
  final String address;
  final String area;
  final double total;
  final double? deliveryPrice;
  final CourierOrderStatus status;
  final String rawStatus;
  final DateTime createdAt;
  final DateTime expectedDeliveryAt;
  final List<CourierOrderItem> items;
  final int itemsCount;
  final String marketName;
  final String marketBranch;
  final int marketCount;
  final String marketSummary;
  final String? addressLabel;
  final String? serviceCityName;
  final String? deliveryAreaName;
  final String? customerAvatarUrl;
  final String? mapQuery;
  final OrderLocation? customerLocation;
  final String? customerNotes;
  final DateTime? deliveredAt;
  final String? deliveryNote;
  final DeliveryProof? deliveryProof;
  final String? deliveryProofUrl;

  factory CourierOrder.fromJson(Map<String, dynamic> json) {
    final customer = _map(json['customer']);
    final address = _map(json['delivery_address']);
    final market = _map(json['market']);
    final serviceCity = _map(json['service_city']);
    final deliveryArea = _map(json['delivery_area']);
    final addressServiceCity = _map(address?['service_city']);
    final addressDeliveryArea = _map(address?['delivery_area']);
    final itemsJson = _list(json['items']);
    final rawStatus = json['status']?.toString() ?? '';
    final status = courierOrderStatusFromRaw(rawStatus);
    final createdAt = _parseDate(json['created_at']);
    final assignedAt = _parseDate(json['assigned_at'], fallback: createdAt);
    final deliveredAt =
        _parseOptionalDate(json['delivered_at']) ??
        _deliveredAtFromHistory(json['history']);
    final items = itemsJson.map(_itemFromJson).toList();
    final label = _clean(address?['name']);
    final details = _clean(address?['details']);
    final manualArea = _clean(address?['manual_area']);
    final manualCity = _clean(address?['manual_city']);
    final areaName =
        _clean(addressDeliveryArea?['name']) ?? _clean(deliveryArea?['name']);
    final cityName =
        _clean(addressServiceCity?['name']) ?? _clean(serviceCity?['name']);
    final formattedAddress = _joinUnique([
      details,
      manualArea,
      manualCity,
      areaName,
      cityName,
    ]);
    final latitude = _optionalNumber(address?['latitude']);
    final longitude = _optionalNumber(address?['longitude']);
    final hasCustomerLocation =
        latitude != null &&
        longitude != null &&
        latitude != 0 &&
        longitude != 0;
    final marketName = _clean(market?['name']) ?? '';
    final marketBranch = _clean(market?['branch']) ?? '';
    final marketCount = _int(json['market_count']);
    final marketNamesSummary = _clean(json['market_names_summary']);

    return CourierOrder(
      id: json['id'].toString(),
      customerName:
          _clean(customer?['name']) ??
          _joinUnique([
            _clean(customer?['first_name']),
            _clean(customer?['last_name']),
          ]) ??
          'عميل',
      phone: _clean(customer?['phone']) ?? '',
      address:
          formattedAddress ??
          label ??
          areaName ??
          cityName ??
          'العنوان غير محدد',
      addressLabel: label,
      area: areaName ?? manualArea ?? cityName ?? manualCity ?? 'غير محدد',
      total: _number(json['total_price']),
      deliveryPrice: _optionalNumber(json['delivery_price']),
      status: status,
      rawStatus: rawStatus,
      createdAt: createdAt,
      expectedDeliveryAt: assignedAt.add(const Duration(hours: 1)),
      items: items,
      itemsCount: _int(
        json['items_count'],
        fallback: _sumItemQuantities(items),
      ),
      marketName: marketName,
      marketBranch: marketBranch,
      marketCount: marketCount,
      marketSummary: _marketSummary(
        marketName: marketName,
        branch: marketBranch,
        count: marketCount,
        namesSummary: marketNamesSummary,
      ),
      serviceCityName: cityName,
      deliveryAreaName: areaName,
      customerAvatarUrl: AuthSession.instance.absoluteUrl(
        customer?['avatar_url'],
      ),
      mapQuery: _joinUnique([formattedAddress, label, areaName, cityName]),
      customerLocation: hasCustomerLocation
          ? OrderLocation(latitude: latitude, longitude: longitude)
          : null,
      customerNotes: _clean(json['description']),
      deliveredAt: deliveredAt,
      deliveryNote: _clean(json['delivery_note']),
      deliveryProofUrl: AuthSession.instance.absoluteUrl(
        json['delivery_proof'],
      ),
    );
  }

  int get itemCount => itemsCount;

  bool get isActiveCourierOrder => status.isActiveCourierOrder;

  bool get isDelivered => status.isDelivered;

  bool get isTerminal => status.isTerminal;

  bool get requiresPickup => status.requiresPickup;

  bool get canMarkPickedUp => status.canMarkPickedUp;

  bool get canMarkDelivered => status.canMarkDelivered;

  CourierOrder copyWith({
    CourierOrderStatus? status,
    String? rawStatus,
    DateTime? deliveredAt,
    String? deliveryNote,
    DeliveryProof? deliveryProof,
    String? deliveryProofUrl,
  }) {
    return CourierOrder(
      id: id,
      customerName: customerName,
      phone: phone,
      address: address,
      area: area,
      total: total,
      deliveryPrice: deliveryPrice,
      status: status ?? this.status,
      rawStatus: rawStatus ?? this.rawStatus,
      createdAt: createdAt,
      expectedDeliveryAt: expectedDeliveryAt,
      items: items,
      itemsCount: itemsCount,
      marketName: marketName,
      marketBranch: marketBranch,
      marketCount: marketCount,
      marketSummary: marketSummary,
      addressLabel: addressLabel,
      serviceCityName: serviceCityName,
      deliveryAreaName: deliveryAreaName,
      customerAvatarUrl: customerAvatarUrl,
      mapQuery: mapQuery,
      customerLocation: customerLocation,
      customerNotes: customerNotes,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      deliveryProof: deliveryProof ?? this.deliveryProof,
      deliveryProofUrl: deliveryProofUrl ?? this.deliveryProofUrl,
    );
  }

  static CourierOrderItem _itemFromJson(Map<String, dynamic> item) {
    final product = _map(item['product']);
    final variant = _map(item['variant']);
    return CourierOrderItem(
      name:
          _clean(item['display_name']) ??
          _clean(item['product_name']) ??
          _clean(product?['name']) ??
          _clean(variant?['name']) ??
          'منتج',
      quantity: _int(item['quantity']),
      price: _number(item['unit_price']),
      subtotal:
          _optionalNumber(item['item_subtotal']) ??
          _optionalNumber(item['subtotal']),
    );
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) return const [];
    return value
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  static DateTime _parseDate(Object? value, {DateTime? fallback}) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
        fallback ??
        DateTime.now();
  }

  static DateTime? _parseOptionalDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  }

  static DateTime? _deliveredAtFromHistory(Object? value) {
    DateTime? latestDeliveredAt;
    for (final event in _list(value)) {
      final toStatus = event['to_status']?.toString().trim().toLowerCase();
      if (toStatus != 'delivered') continue;

      final createdAt = _parseOptionalDate(event['created_at']);
      if (createdAt == null) continue;
      if (latestDeliveredAt == null || createdAt.isAfter(latestDeliveredAt)) {
        latestDeliveredAt = createdAt;
      }
    }
    return latestDeliveredAt;
  }

  static double _number(Object? value) => _optionalNumber(value) ?? 0;

  static double? _optionalNumber(Object? value) {
    return double.tryParse(value?.toString() ?? '');
  }

  static int _int(Object? value, {int fallback = 0}) {
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _sumItemQuantities(List<CourierOrderItem> items) {
    return items.fold<int>(0, (total, item) => total + item.quantity);
  }

  static String? _clean(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _joinUnique(Iterable<String?> values) {
    final parts = <String>[];
    for (final value in values) {
      final text = _clean(value);
      if (text == null) continue;
      if (!parts.contains(text)) parts.add(text);
    }
    return parts.isEmpty ? null : parts.join('، ');
  }

  static String _marketSummary({
    required String marketName,
    required String branch,
    required int count,
    required String? namesSummary,
  }) {
    if (count > 1) {
      return namesSummary?.isNotEmpty == true ? namesSummary! : '$count محلات';
    }
    return _joinUnique([marketName, branch]) ?? 'المحل غير محدد';
  }
}
