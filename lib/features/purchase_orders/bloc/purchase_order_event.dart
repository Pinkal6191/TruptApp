import 'package:equatable/equatable.dart';
import '../data/purchase_order_model.dart';

abstract class PurchaseOrderEvent extends Equatable {
  const PurchaseOrderEvent();

  @override
  List<Object> get props => [];
}

class LoadPurchaseOrders extends PurchaseOrderEvent {}

class CreatePurchaseOrder extends PurchaseOrderEvent {
  final PurchaseOrderModel purchaseOrder;

  const CreatePurchaseOrder(this.purchaseOrder);

  @override
  List<Object> get props => [purchaseOrder];
}
