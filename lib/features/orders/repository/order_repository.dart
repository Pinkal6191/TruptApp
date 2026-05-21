import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/order_model.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../../inventory/repository/production_repository.dart';

class OrderRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'orders';
  final InventoryRepository _inventoryRepository = InventoryRepository();
  final ProductionRepository _productionRepository = ProductionRepository();

  Future<void> createOrder(OrderModel order) async {
    try {
      await _firestore.collection(collectionName).add(order.toMap());
      
      // Stock Maintenance at creation (When Bill is Generated)
      for (var item in order.items) {
        if (order.creatorRole == 'distributor') {
          // Distributor selling to Retailer -> Decrease Distributor's stock immediately
          await _inventoryRepository.updateStock(order.createdBy, item.productId, item.productName, -item.quantity);
        } else if (order.creatorRole == 'admin' && order.isSupplyOrder) {
          // Admin supplying to Distributor -> Increase Distributor's stock immediately
          await _inventoryRepository.updateStock(order.targetUserId, item.productId, item.productName, item.quantity);
        }

        // Factory Stock Maintenance for Admin dispatches (both Supply & Retail/Direct orders)
        if (order.creatorRole == 'admin') {
          await _productionRepository.updateFactoryStock(item.productId, item.productName, -item.quantity);
        }
      }
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  // Version: 1.0.2 - Support referredPartnerId and partnerName fallbacks
  Future<List<OrderModel>> getOrdersByUser(String userId, {String? userName}) async {
    try {
      final List<Future<QuerySnapshot>> futures = [
        _firestore.collection(collectionName).where('createdBy', isEqualTo: userId).get(),
        _firestore.collection(collectionName).where('referredPartnerId', isEqualTo: userId).get(),
      ];
      
      if (userName != null && userName.isNotEmpty) {
        futures.add(_firestore.collection(collectionName).where('partnerName', isEqualTo: userName).get());
      }
      
      final snapshots = await Future.wait(futures);
      final map = <String, OrderModel>{};
      for (var snap in snapshots) {
        for (var doc in snap.docs) {
          final order = OrderModel.fromFirestore(doc);
          map[order.id] = order;
        }
      }
      
      final orders = map.values.toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } catch (e) {
      throw Exception('Failed to get user orders: $e');
    }
  }

  Stream<List<OrderModel>> watchOrdersByUser(String userId, {String? userName}) {
    final controller = StreamController<List<OrderModel>>();
    final List<StreamSubscription<QuerySnapshot>> subscriptions = [];
    final Map<int, List<OrderModel>> lists = {};
    
    void emitCombined() {
      final map = <String, OrderModel>{};
      for (var list in lists.values) {
        for (var o in list) {
          map[o.id] = o;
        }
      }
      final combined = map.values.toList();
      combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) {
        controller.add(combined);
      }
    }
    
    final streams = [
      _firestore.collection(collectionName).where('createdBy', isEqualTo: userId).snapshots(),
      _firestore.collection(collectionName).where('referredPartnerId', isEqualTo: userId).snapshots(),
    ];
    
    if (userName != null && userName.isNotEmpty) {
      streams.add(_firestore.collection(collectionName).where('partnerName', isEqualTo: userName).snapshots());
    }
    
    for (int i = 0; i < streams.length; i++) {
      final sub = streams[i].listen((snapshot) {
        lists[i] = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
        emitCombined();
      }, onError: (err) {
        if (!controller.isClosed) controller.addError(err);
      });
      subscriptions.add(sub);
    }
    
    controller.onCancel = () {
      for (var sub in subscriptions) {
        sub.cancel();
      }
    };
    
    return controller.stream;
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
      await _firestore.collection(collectionName).doc(orderId).update({statusType: newStatus});
    } catch (e) {
      throw Exception('Failed to update order status: $e');
    }
  }

  Future<void> updateOrderPayment(String orderId, double paidAmount, String paymentStatus) async {
    try {
      final doc = await _firestore.collection(collectionName).doc(orderId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final double finalAmount = (data['finalAmount'] ?? 0.0).toDouble();
        // Store actual remaining (can be negative to indicate overpayment/change due to customer)
        final double remaining = finalAmount - paidAmount;
        await _firestore.collection(collectionName).doc(orderId).update({
          'paidAmount': paidAmount,
          'remainingAmount': remaining,
          'paymentStatus': paymentStatus,
        });
      }
    } catch (e) {
      throw Exception('Failed to update payment: $e');
    }
  }

  Future<String> generateInvoiceNumber(bool isSupplyOrder, String creatorRole) async {
    try {
      final String counterId = isSupplyOrder 
          ? 'supply' 
          : (creatorRole.toLowerCase() == 'distributor' ? 'distributor' : 'partner');
      
      final DocumentReference counterRef = _firestore.collection('metadata').doc('invoice_counters');
      
      final nextNumber = await _firestore.runTransaction<int>((transaction) async {
        final snapshot = await transaction.get(counterRef);
        int currentCount = 0;
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          if (data != null) {
            currentCount = data[counterId] ?? 0;
          }
        }
        final nextCount = currentCount + 1;
        transaction.set(counterRef, {counterId: nextCount}, SetOptions(merge: true));
        return nextCount;
      });

      final formattedNumber = nextNumber.toString().padLeft(2, '0');
      
      if (isSupplyOrder) {
        return 'S-$formattedNumber'; // S for Supply (Admin to Distributor)
      } else if (creatorRole.toLowerCase() == 'distributor') {
        return 'D$formattedNumber'; // D for Distributor sale
      } else {
        return formattedNumber; // Default/Partner sale
      }
    } catch (e) {
      // Fallback if transaction fails
      return DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    }
  }

  Future<void> updateOrder(OrderModel newOrder) async {
    try {
      // 1. Get existing order from Firestore
      DocumentSnapshot doc = await _firestore.collection(collectionName).doc(newOrder.id).get();
      if (!doc.exists) {
        throw Exception('Order not found');
      }
      OrderModel oldOrder = OrderModel.fromFirestore(doc);

      // 2. Reverse old stock changes
      for (var item in oldOrder.items) {
        if (oldOrder.creatorRole == 'distributor') {
          await _inventoryRepository.updateStock(oldOrder.createdBy, item.productId, item.productName, item.quantity);
        } else if (oldOrder.creatorRole == 'admin' && oldOrder.isSupplyOrder) {
          await _inventoryRepository.updateStock(oldOrder.targetUserId, item.productId, item.productName, -item.quantity);
        }
        if (oldOrder.creatorRole == 'admin') {
          await _productionRepository.updateFactoryStock(item.productId, item.productName, item.quantity);
        }
      }

      // 3. Apply new stock changes
      for (var item in newOrder.items) {
        if (newOrder.creatorRole == 'distributor') {
          await _inventoryRepository.updateStock(newOrder.createdBy, item.productId, item.productName, -item.quantity);
        } else if (newOrder.creatorRole == 'admin' && newOrder.isSupplyOrder) {
          await _inventoryRepository.updateStock(newOrder.targetUserId, item.productId, item.productName, item.quantity);
        }
        if (newOrder.creatorRole == 'admin') {
          await _productionRepository.updateFactoryStock(item.productId, item.productName, -item.quantity);
        }
      }

      // 4. Update order in Firestore
      await _firestore.collection(collectionName).doc(newOrder.id).update(newOrder.toMap());
    } catch (e) {
      throw Exception('Failed to update order: $e');
    }
  }

  Future<void> deleteOrder(OrderModel order) async {
    try {
      await _firestore.collection(collectionName).doc(order.id).delete();
      
      // Reverse Stock Maintenance
      for (var item in order.items) {
        if (order.creatorRole == 'distributor') {
          // Reverse distributor selling to Retailer -> Increase Distributor's stock back
          await _inventoryRepository.updateStock(order.createdBy, item.productId, item.productName, item.quantity);
        } else if (order.creatorRole == 'admin' && order.isSupplyOrder) {
          // Reverse admin supplying to Distributor -> Decrease Distributor's stock back
          await _inventoryRepository.updateStock(order.targetUserId, item.productId, item.productName, -item.quantity);
        }

        // Reverse Factory Stock Maintenance for Admin dispatches
        if (order.creatorRole == 'admin') {
          await _productionRepository.updateFactoryStock(item.productId, item.productName, item.quantity);
        }
      }
    } catch (e) {
      throw Exception('Failed to delete order: $e');
    }
  }
}
