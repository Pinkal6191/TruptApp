import '../../../core/models/order_model.dart';

abstract class OrderState {}

class OrderInitial extends OrderState {}

class OrderLoading extends OrderState {}

class OrdersLoaded extends OrderState {
  final List<OrderModel> orders;
  OrdersLoaded({required this.orders});
}

class OrderOperationSuccess extends OrderState {
  final String message;
  OrderOperationSuccess({required this.message});
}

class OrderError extends OrderState {
  final String message;
  OrderError({required this.message});
}
