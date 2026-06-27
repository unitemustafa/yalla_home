import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/auth/auth_session.dart';

enum CourierOrderStatus { assigned, delivered }

extension CourierOrderStatusLabel on CourierOrderStatus {
  String get label {
    return switch (this) {
      CourierOrderStatus.assigned => 'مطلوب الاستلام',
      CourierOrderStatus.delivered => 'تم التسليم',
    };
  }

  Color get color {
    return switch (this) {
      CourierOrderStatus.assigned => AppColors.info,
      CourierOrderStatus.delivered => AppColors.success,
    };
  }
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
  });

  final String name;
  final int quantity;
  final double price;
}

class CourierOrder {
  const CourierOrder({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.area,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.expectedDeliveryAt,
    required this.items,
    this.customerAvatarUrl,
    this.mapQuery,
    this.customerLocation,
    this.customerNotes,
    this.deliveredAt,
    this.deliveryNote,
    this.deliveryProof,
  });

  final String id;
  final String customerName;
  final String phone;
  final String address;
  final String area;
  final double total;
  final CourierOrderStatus status;
  final DateTime createdAt;
  final DateTime expectedDeliveryAt;
  final List<CourierOrderItem> items;
  final String? customerAvatarUrl;
  final String? mapQuery;
  final OrderLocation? customerLocation;
  final String? customerNotes;
  final DateTime? deliveredAt;
  final String? deliveryNote;
  final DeliveryProof? deliveryProof;

  factory CourierOrder.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? const {};
    final address = json['delivery_address'] as Map<String, dynamic>?;
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    final status = json['status'] == 'delivered'
        ? CourierOrderStatus.delivered
        : CourierOrderStatus.assigned;
    DateTime parseDate(Object? value, {DateTime? fallback}) =>
        DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
        fallback ??
        DateTime.now();
    double number(Object? value) =>
        double.tryParse(value?.toString() ?? '') ?? 0;
    final firstName = customer['first_name']?.toString().trim() ?? '';
    final lastName = customer['last_name']?.toString().trim() ?? '';
    final createdAt = parseDate(json['created_at']);
    return CourierOrder(
      id: json['id'].toString(),
      customerName: [
        firstName,
        lastName,
      ].where((part) => part.isNotEmpty).join(' '),
      phone: customer['phone']?.toString() ?? '',
      address: address?['name']?.toString() ?? 'موقع العميل',
      area: address?['name']?.toString() ?? 'غير محدد',
      total: number(json['total_price']),
      status: status,
      createdAt: createdAt,
      expectedDeliveryAt: parseDate(
        json['assigned_at'],
        fallback: createdAt,
      ).add(const Duration(hours: 1)),
      items: itemsJson.whereType<Map<String, dynamic>>().map((item) {
        final variant = item['variant'] as Map<String, dynamic>? ?? const {};
        final product = variant['product'] as Map<String, dynamic>? ?? const {};
        return CourierOrderItem(
          name: product['name']?.toString() ?? 'منتج',
          quantity: int.tryParse(item['quantity']?.toString() ?? '') ?? 0,
          price: number(item['unit_price']),
        );
      }).toList(),
      customerAvatarUrl: AuthSession.instance.absoluteUrl(
        customer['avatar_url'],
      ),
      mapQuery: address?['name']?.toString(),
      customerLocation: address == null
          ? null
          : OrderLocation(
              latitude: number(address['latitude']),
              longitude: number(address['longitude']),
            ),
      customerNotes: (json['description']?.toString().trim().isEmpty ?? true)
          ? null
          : json['description'].toString(),
      deliveredAt: json['delivered_at'] == null
          ? null
          : parseDate(json['delivered_at']),
      deliveryNote: (json['delivery_note']?.toString().trim().isEmpty ?? true)
          ? null
          : json['delivery_note'].toString(),
    );
  }

  int get itemCount {
    return items.fold<int>(0, (total, item) => total + item.quantity);
  }

  bool get isDelivered => status == CourierOrderStatus.delivered;

  CourierOrder copyWith({
    CourierOrderStatus? status,
    DateTime? deliveredAt,
    String? deliveryNote,
    DeliveryProof? deliveryProof,
  }) {
    return CourierOrder(
      id: id,
      customerName: customerName,
      phone: phone,
      address: address,
      area: area,
      total: total,
      status: status ?? this.status,
      createdAt: createdAt,
      expectedDeliveryAt: expectedDeliveryAt,
      items: items,
      customerAvatarUrl: customerAvatarUrl,
      mapQuery: mapQuery,
      customerLocation: customerLocation,
      customerNotes: customerNotes,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      deliveryProof: deliveryProof ?? this.deliveryProof,
    );
  }
}
