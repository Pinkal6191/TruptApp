import '../../../core/models/order_model.dart';

abstract class OrderEvent {}

class LoadOrders extends OrderEvent {
  final String? userId; // If null, load all (for admin)
  final String? userName;
  LoadOrders({this.userId, this.userName});
}

class LoadAllOrders extends OrderEvent {}
class WatchOrders extends OrderEvent {
  final String? userId;
  final String? userName;
  WatchOrders({this.userId, this.userName});
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

class UpdateOrder extends OrderEvent {
  final OrderModel order;
  final String? userId;
  final String? userName;
  UpdateOrder({required this.order, this.userId, this.userName});
}

class UpdateOrderStatus extends OrderEvent {
  final String orderId;
  final String statusType; // 'deliveryStatus' or 'paymentStatus'
  final String newStatus;
  final String? userId;
  final String? userName;

  UpdateOrderStatus({
    required this.orderId,
    required this.statusType,
    required this.newStatus,
    this.userId,
    this.userName,
  });
}

class UpdateOrderPayment extends OrderEvent {
  final String orderId;
  final double paidAmount;
  final String paymentStatus;
  final double? previousPaidAmount;
  final String? userId;
  final String? userName;
  final String? paymentMethod;

  UpdateOrderPayment({
    required this.orderId,
    required this.paidAmount,
    required this.paymentStatus,
    this.previousPaidAmount,
    this.userId,
    this.userName,
    this.paymentMethod,
  });
}

class DeleteOrder extends OrderEvent {
  final OrderModel order;
  final String? userId;
  final String? userName;

  DeleteOrder({
    required this.order,
    this.userId,
    this.userName,
  });
}
