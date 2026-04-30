import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/order_model.dart';

class OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'orders';

  Future<void> createOrder(OrderModel order) async {
    try {
      await _firestore.collection(collectionName).add(order.toMap());
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  Future<List<OrderModel>> getOrdersByUser(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get user orders: $e');
    }
  }

  Future<List<OrderModel>> getAllOrders() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get all orders: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String statusType, String newStatus) async {
    try {
      await _firestore.collection(collectionName).doc(orderId).update({
        statusType: newStatus,
      });
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  Future<void> updateOrderPayment(String orderId, double paidAmount, String paymentStatus) async {
    try {
      await _firestore.collection(collectionName).doc(orderId).update({
        'paidAmount': paidAmount,
        'paymentStatus': paymentStatus,
      });
    } catch (e) {
      throw Exception('Failed to update payment: $e');
    }
  }
}
