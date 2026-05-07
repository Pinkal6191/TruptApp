import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/order_model.dart';
import '../../inventory/repository/inventory_repository.dart';

class OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'orders';
  final InventoryRepository _inventoryRepository = InventoryRepository();

  Future<void> createOrder(OrderModel order) async {
    try {
      await _firestore.collection(collectionName).add(order.toMap());
      
      // If a distributor is creating an order (Selling to Partner), decrease their stock immediately?
      // Or should it wait for Delivery?
      // User said: "stock reflect after delivery complete"
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  // Version: 1.0.1 - Client side sorting active
  Future<List<OrderModel>> getOrdersByUser(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .where('createdBy', isEqualTo: userId)
          .get();
      
      final orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      
      // Sort client-side to avoid Firestore Index requirement
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return orders;
    } catch (e) {
      throw Exception('Failed to get user orders: $e');
    }
  }

  Stream<List<OrderModel>> watchOrdersByUser(String userId) {
    return _firestore
        .collection(collectionName)
        .where('createdBy', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  Future<List<OrderModel>> getAllOrders() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .get();
      
      final orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return orders;
    } catch (e) {
      throw Exception('Failed to get all orders: $e');
    }
  }

  Stream<List<OrderModel>> watchAllOrders() {
    return _firestore
        .collection(collectionName)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  Future<void> updateOrderStatus(String orderId, String statusType, String newStatus) async {
    try {
      final docRef = _firestore.collection(collectionName).doc(orderId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;
      
      final order = OrderModel.fromFirestore(snapshot);
      final oldStatus = statusType == 'deliveryStatus' ? order.deliveryStatus : '';

      await docRef.update({statusType: newStatus});

      // Handle Stock Logic on Delivery
      if (statusType == 'deliveryStatus' && newStatus == 'Delivered' && oldStatus != 'Delivered') {
        for (var item in order.items) {
          if (order.creatorRole == 'distributor') {
            // Distributor selling to Retailer -> Decrease Distributor's stock
            await _inventoryRepository.updateStock(order.createdBy, item.productId, item.productName, -item.quantity);
          } else if (order.creatorRole == 'admin' && order.isSupplyOrder) {
            // Admin supplying to Distributor -> Increase Distributor's stock
            // In this case, targetUserId is the Distributor's UID
            await _inventoryRepository.updateStock(order.targetUserId, item.productId, item.productName, item.quantity);
          }
        }
      }
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

  Future<String> generateInvoiceNumber(bool isSupplyOrder) async {
    try {
      final snapshot = await _firestore.collection(collectionName).get();
      int count = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final bool docIsSupply = data['isSupplyOrder'] ?? false;
        if (docIsSupply == isSupplyOrder) {
          count++;
        }
      }
      
      final nextNumber = count + 1;
      final formattedNumber = nextNumber.toString().padLeft(2, '0');
      
      if (isSupplyOrder) {
        return 'd-$formattedNumber';
      } else {
        return formattedNumber;
      }
    } catch (e) {
      // Fallback if counting fails
      return DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    }
  }
}
