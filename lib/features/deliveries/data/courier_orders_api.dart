import '../../../core/auth/auth_session.dart';
import '../domain/courier_order.dart';

class CourierOrdersApi {
  const CourierOrdersApi();

  Future<List<CourierOrder>> loadOrders() async {
    final data = await AuthSession.instance.getJson('courier/orders/');
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(CourierOrder.fromJson)
        .toList();
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
