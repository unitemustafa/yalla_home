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

  Future<CourierOrder> deliver(
    String orderId, {
    String? note,
    DeliveryProof? proof,
  }) async {
    final data = await AuthSession.instance.postMultipart(
      'orders/$orderId/deliver/',
      note: note,
      proofBytes: proof?.bytes,
      proofName: proof?.fileName,
    );
    return CourierOrder.fromJson(data as Map<String, dynamic>);
  }
}
