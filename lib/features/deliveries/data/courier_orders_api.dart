import '../../../core/auth/auth_session.dart';
import '../domain/courier_order.dart';

class CourierOrdersApi {
  const CourierOrdersApi();

  Future<List<CourierOrder>> loadOrders() async {
    final data = await AuthSession.instance.getJson('courier/orders/');
    final rows = data is Map<String, dynamic> ? data['results'] : data;
    return (rows as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(CourierOrder.fromJson)
        .toList();
  }

  Future<CourierOrder> loadOrder(String orderId) async {
    final data = await AuthSession.instance.getJson('courier/orders/$orderId/');
    return CourierOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<CourierOrder> markPickedUp(String orderId) async {
    final data = await AuthSession.instance.patchJson(
      'courier/orders/$orderId/status/',
      {'status': 'picked_up'},
    );
    return CourierOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<CourierOrder> markDelivered(
    String orderId, {
    String? note,
    List<int>? proofBytes,
    String? proofName,
  }) async {
    final deliveryNote = note?.trim();
    final fields = <String, String>{
      'status': 'delivered',
      if (deliveryNote != null && deliveryNote.isNotEmpty)
        'delivery_note': deliveryNote,
    };
    final data = proofBytes == null || proofName == null
        ? await AuthSession.instance.patchJson(
            'courier/orders/$orderId/status/',
            fields,
          )
        : await AuthSession.instance.patchMultipart(
            'courier/orders/$orderId/status/',
            fields: fields,
            proofBytes: proofBytes,
            proofName: proofName,
          );
    return CourierOrder.fromJson(data as Map<String, dynamic>);
  }
}
