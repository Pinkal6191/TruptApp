import '../../../core/models/order_model.dart';

abstract class OrderEvent {}

class LoadOrders extends OrderEvent {
  final String? userId; // If null, load all (for admin)
  LoadOrders({this.userId});
}

class LoadAllOrders extends OrderEvent {}
class WatchOrders extends OrderEvent {
  final String? userId;
  WatchOrders({this.userId});
}
class OrdersUpdated extends OrderEvent {
  final List<OrderModel> orders;
  OrdersUpdated(this.orders);
}
class ResetOrderState extends OrderEvent {}

class CreateOrder extends OrderEvent {
  final OrderModel order;
  CreateOrder({required this.order});
}

class UpdateOrderStatus extends OrderEvent {
  final String orderId;
  final String statusType; // 'deliveryStatus' or 'paymentStatus'
  final String newStatus;

  UpdateOrderStatus({
    required this.orderId,
    required this.statusType,
    required this.newStatus,
  });
}

class UpdateOrderPayment extends OrderEvent {
  final String orderId;
  final double paidAmount;
  final String paymentStatus;

  UpdateOrderPayment({
    required this.orderId,
    required this.paidAmount,
    required this.paymentStatus,
  });
}
