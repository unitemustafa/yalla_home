import '../domain/courier_order.dart';

class DemoCourierOrders {
  DemoCourierOrders._();

  static List<CourierOrder> initialOrders() {
    final now = DateTime.now();

    return [
      CourierOrder(
        id: 'YM-10284',
        customerName: 'أحمد مصطفى',
        phone: '+201001234567',
        address: 'شارع التحرير، الدقي، الدور الرابع، بجوار بنك مصر',
        area: 'الدقي',
        total: 845,
        status: CourierOrderStatus.assigned,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 20)),
        expectedDeliveryAt: now.add(const Duration(minutes: 35)),
        customerAvatarUrl:
            'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=160&q=80',
        mapQuery: 'شارع التحرير الدقي بنك مصر',
        customerLocation: const OrderLocation(
          latitude: 30.038560,
          longitude: 31.211820,
        ),
        customerNotes: 'اتصل قبل الوصول بخمس دقائق.',
        items: const [
          CourierOrderItem(name: 'باقة خضار طازة', quantity: 1, price: 320),
          CourierOrderItem(name: 'رز بسمتي 5 كيلو', quantity: 2, price: 210),
          CourierOrderItem(name: 'عسل أبيض', quantity: 1, price: 105),
        ],
      ),
      CourierOrder(
        id: 'YM-10291',
        customerName: 'منة خالد',
        phone: '+201112345678',
        address: 'كمبوند دار مصر، التجمع الخامس، بوابة 3، عمارة 12',
        area: 'التجمع الخامس',
        total: 1260,
        status: CourierOrderStatus.assigned,
        createdAt: now.subtract(const Duration(minutes: 48)),
        expectedDeliveryAt: now.add(const Duration(hours: 1, minutes: 10)),
        customerAvatarUrl:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=160&q=80',
        mapQuery: 'دار مصر التجمع الخامس بوابة 3',
        customerLocation: const OrderLocation(
          latitude: 30.007600,
          longitude: 31.462280,
        ),
        items: const [
          CourierOrderItem(name: 'منظف أرضيات', quantity: 3, price: 95),
          CourierOrderItem(name: 'حفاضات أطفال', quantity: 2, price: 430),
          CourierOrderItem(name: 'مناديل مطبخ', quantity: 1, price: 115),
        ],
      ),
      CourierOrder(
        id: 'YM-10302',
        customerName: 'سارة عادل',
        phone: '+201223456789',
        address: 'مدينة نصر، شارع عباس العقاد، برج اللوتس، شقة 82',
        area: 'مدينة نصر',
        total: 510,
        status: CourierOrderStatus.assigned,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 5)),
        expectedDeliveryAt: now.add(const Duration(minutes: 55)),
        customerAvatarUrl:
            'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?auto=format&fit=crop&w=160&q=80',
        mapQuery: 'عباس العقاد برج اللوتس مدينة نصر',
        customerLocation: const OrderLocation(
          latitude: 30.062050,
          longitude: 31.337410,
        ),
        customerNotes: 'الدفع كاش عند الاستلام.',
        items: const [
          CourierOrderItem(name: 'قهوة تركي', quantity: 2, price: 160),
          CourierOrderItem(name: 'لبن كامل الدسم', quantity: 4, price: 38),
          CourierOrderItem(name: 'كرواسون', quantity: 3, price: 26),
        ],
      ),
      CourierOrder(
        id: 'YM-10270',
        customerName: 'كريم سامي',
        phone: '+201334567890',
        address: 'المعادي، شارع 9، أمام محطة المترو',
        area: 'المعادي',
        total: 390,
        status: CourierOrderStatus.delivered,
        createdAt: now.subtract(const Duration(hours: 4, minutes: 30)),
        expectedDeliveryAt: now.subtract(const Duration(hours: 2, minutes: 55)),
        deliveredAt: now.subtract(const Duration(hours: 2, minutes: 42)),
        deliveryNote: 'تم التسليم للعميل شخصيًا.',
        mapQuery: 'شارع 9 المعادي محطة المترو',
        customerLocation: const OrderLocation(
          latitude: 29.960450,
          longitude: 31.258940,
        ),
        items: const [
          CourierOrderItem(name: 'مياه معدنية', quantity: 6, price: 20),
          CourierOrderItem(name: 'عصير برتقال', quantity: 3, price: 45),
          CourierOrderItem(name: 'خبز بلدي', quantity: 5, price: 27),
        ],
      ),
    ];
  }
}
