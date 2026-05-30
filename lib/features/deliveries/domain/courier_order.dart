import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

enum CourierOrderStatus { assigned, pickedUp, onTheWay, delivered }

extension CourierOrderStatusLabel on CourierOrderStatus {
  String get label {
    return switch (this) {
      CourierOrderStatus.assigned => 'مطلوب الاستلام',
      CourierOrderStatus.pickedUp => 'تم الاستلام',
      CourierOrderStatus.onTheWay => 'في الطريق',
      CourierOrderStatus.delivered => 'تم التسليم',
    };
  }

  Color get color {
    return switch (this) {
      CourierOrderStatus.assigned => AppColors.info,
      CourierOrderStatus.pickedUp => AppColors.warning,
      CourierOrderStatus.onTheWay => AppColors.primary,
      CourierOrderStatus.delivered => AppColors.success,
    };
  }
}

class DeliveryProof {
  const DeliveryProof({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
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
    this.mapQuery,
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
  final String? mapQuery;
  final String? customerNotes;
  final DateTime? deliveredAt;
  final String? deliveryNote;
  final DeliveryProof? deliveryProof;

  int get itemCount {
    return items.fold<int>(0, (total, item) => total + item.quantity);
  }

  bool get isDelivered => status == CourierOrderStatus.delivered;

  bool get deliveredToday {
    final value = deliveredAt;
    if (value == null) return false;
    final now = DateTime.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }

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
      mapQuery: mapQuery,
      customerNotes: customerNotes,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      deliveryProof: deliveryProof ?? this.deliveryProof,
    );
  }
}
