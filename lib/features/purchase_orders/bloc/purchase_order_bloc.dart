import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/purchase_order_model.dart';
import 'purchase_order_event.dart';
import 'purchase_order_state.dart';

class PurchaseOrderBloc extends Bloc<PurchaseOrderEvent, PurchaseOrderState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PurchaseOrderBloc() : super(PurchaseOrderInitial()) {
    on<LoadPurchaseOrders>(_onLoadPurchaseOrders);
    on<CreatePurchaseOrder>(_onCreatePurchaseOrder);
  }

  Future<void> _onLoadPurchaseOrders(LoadPurchaseOrders event, Emitter<PurchaseOrderState> emit) async {
    emit(PurchaseOrderLoading());
    try {
      final snapshot = await _firestore
          .collection('purchase_orders')
          .orderBy('createdAt', descending: true)
          .get();

      final purchaseOrders = snapshot.docs
          .map((doc) => PurchaseOrderModel.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      emit(PurchaseOrdersLoaded(purchaseOrders));
    } catch (e) {
      emit(PurchaseOrderError(e.toString()));
    }
  }

  Future<void> _onCreatePurchaseOrder(CreatePurchaseOrder event, Emitter<PurchaseOrderState> emit) async {
    emit(PurchaseOrderLoading());
    try {
      final docRef = _firestore.collection('purchase_orders').doc();
      
      final poData = event.purchaseOrder.toMap();
      poData['id'] = docRef.id;

      await docRef.set(poData);

      emit(PurchaseOrderCreated());
      add(LoadPurchaseOrders()); // Reload list after creation
    } catch (e) {
      emit(PurchaseOrderError(e.toString()));
      add(LoadPurchaseOrders()); // Try to reload if it fails to restore state
    }
  }
}
