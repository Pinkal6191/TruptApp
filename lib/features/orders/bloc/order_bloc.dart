import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/order_repository.dart';
import 'order_event.dart';
import 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository _orderRepository;

  OrderBloc({required OrderRepository orderRepository})
      : _orderRepository = orderRepository,
        super(OrderInitial()) {
    on<LoadOrders>(_onLoadOrders);
    on<CreateOrder>(_onCreateOrder);
    on<UpdateOrderStatus>(_onUpdateOrderStatus);
    on<UpdateOrderPayment>(_onUpdateOrderPayment);
  }

  Future<void> _onLoadOrders(LoadOrders event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      if (event.userId != null) {
        final orders = await _orderRepository.getOrdersByUser(event.userId!);
        emit(OrdersLoaded(orders: orders));
      } else {
        final orders = await _orderRepository.getAllOrders();
        emit(OrdersLoaded(orders: orders));
      }
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  Future<void> _onCreateOrder(CreateOrder event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      await _orderRepository.createOrder(event.order);
      emit(OrderOperationSuccess(message: 'Order created successfully!'));
      // Reload orders for the user who created it.
      add(LoadOrders(userId: event.order.createdBy)); 
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  Future<void> _onUpdateOrderStatus(UpdateOrderStatus event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      await _orderRepository.updateOrderStatus(event.orderId, event.statusType, event.newStatus);
      emit(OrderOperationSuccess(message: 'Order status updated!'));
      add(LoadOrders()); 
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  Future<void> _onUpdateOrderPayment(UpdateOrderPayment event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      await _orderRepository.updateOrderPayment(event.orderId, event.paidAmount, event.paymentStatus);
      emit(OrderOperationSuccess(message: 'Payment recorded successfully!'));
      add(LoadOrders()); 
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }
}
