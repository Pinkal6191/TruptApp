import 'package:equatable/equatable.dart';
import '../data/purchase_order_model.dart';

abstract class PurchaseOrderState extends Equatable {
  const PurchaseOrderState();

  @override
  List<Object> get props => [];
}

class PurchaseOrderInitial extends PurchaseOrderState {}

class PurchaseOrderLoading extends PurchaseOrderState {}

class PurchaseOrdersLoaded extends PurchaseOrderState {
  final List<PurchaseOrderModel> purchaseOrders;

  const PurchaseOrdersLoaded(this.purchaseOrders);

  @override
  List<Object> get props => [purchaseOrders];
}

class PurchaseOrderError extends PurchaseOrderState {
  final String message;

  const PurchaseOrderError(this.message);

  @override
  List<Object> get props => [message];
}

class PurchaseOrderCreated extends PurchaseOrderState {}
