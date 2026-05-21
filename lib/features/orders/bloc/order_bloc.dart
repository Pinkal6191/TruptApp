import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/order_repository.dart';
import 'order_event.dart';
import 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository _orderRepository;
  StreamSubscription? _ordersSubscription;

  OrderBloc({required OrderRepository orderRepository})
      : _orderRepository = orderRepository,
        super(OrderInitial()) {
    on<LoadOrders>(_onLoadOrders);
    on<LoadAllOrders>(_onLoadAllOrders);
    on<WatchOrders>(_onWatchOrders);
    on<OrdersUpdated>((event, emit) => emit(OrdersLoaded(orders: event.orders)));
    on<ResetOrderState>(_onResetOrderState);
    on<CreateOrder>(_onCreateOrder);
    on<UpdateOrder>(_onUpdateOrder);
    on<UpdateOrderStatus>(_onUpdateOrderStatus);
    on<UpdateOrderPayment>(_onUpdateOrderPayment);
    on<DeleteOrder>(_onDeleteOrder);
  }

  void _onResetOrderState(ResetOrderState event, Emitter<OrderState> emit) {
    _ordersSubscription?.cancel();
    emit(OrderInitial());
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
  Future<void> _onLoadAllOrders(LoadAllOrders event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      final orders = await _orderRepository.getAllOrders();
      emit(OrdersLoaded(orders: orders));
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  void _onWatchOrders(WatchOrders event, Emitter<OrderState> emit) {
    emit(OrderLoading());
    _ordersSubscription?.cancel();
    final stream = event.userId != null 
        ? _orderRepository.watchOrdersByUser(event.userId!) 
        : _orderRepository.watchAllOrders();
    
    _ordersSubscription = stream.listen(
      (orders) => add(OrdersUpdated(orders)),
      onError: (error) => emit(OrderError(message: error.toString())),
    );
  }

  @override
  Future<void> close() {
    _ordersSubscription?.cancel();
    return super.close();
  }

  Future<void> _onCreateOrder(CreateOrder event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      await _orderRepository.createOrder(event.order);
      emit(OrderOperationSuccess(message: 'Order created successfully!'));
      // Admin sees all orders; partner/distributor sees only their own
      if (event.order.creatorRole == 'admin') {
        add(LoadOrders());
      } else {
        add(LoadOrders(userId: event.order.createdBy));
      }
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  Future<void> _onUpdateOrder(UpdateOrder event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      await _orderRepository.updateOrder(event.order);
      emit(OrderOperationSuccess(message: 'Order updated successfully!'));
      if (event.order.creatorRole == 'admin') {
        add(LoadOrders());
      } else {
        add(LoadOrders(userId: event.order.createdBy));
      }
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  Future<void> _onUpdateOrderStatus(UpdateOrderStatus event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      await _orderRepository.updateOrderStatus(event.orderId, event.statusType, event.newStatus);
      emit(OrderOperationSuccess(message: 'Order status updated!'));
      add(LoadOrders(userId: event.userId)); 
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  Future<void> _onUpdateOrderPayment(UpdateOrderPayment event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      await _orderRepository.updateOrderPayment(event.orderId, event.paidAmount, event.paymentStatus);
      emit(OrderOperationSuccess(message: 'Payment recorded successfully!'));
      add(LoadOrders(userId: event.userId)); 
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }

  Future<void> _onDeleteOrder(DeleteOrder event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      await _orderRepository.deleteOrder(event.order);
      emit(OrderOperationSuccess(message: 'Order deleted successfully!'));
      add(LoadOrders(userId: event.userId)); 
    } catch (e) {
      emit(OrderError(message: e.toString()));
    }
  }
}
