import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/customer_model.dart';
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

      // Sync Customer automatically!
      await _updateCustomerOnOrderCreated(order);
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  // Version: 1.0.3 - Support referredPartnerId, targetUserId, and partnerName fallbacks
  Future<List<OrderModel>> getOrdersByUser(String userId, {String? userName}) async {
    try {
      final List<Future<QuerySnapshot>> futures = [
        _firestore.collection(collectionName).where('createdBy', isEqualTo: userId).get(),
        _firestore.collection(collectionName).where('referredPartnerId', isEqualTo: userId).get(),
        _firestore.collection(collectionName).where('targetUserId', isEqualTo: userId).get(),
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
      _firestore.collection(collectionName).where('targetUserId', isEqualTo: userId).snapshots(),
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

  Future<void> updateOrderPayment(String orderId, double paidAmount, String paymentStatus, {double? previousPaidAmount, String? paymentNote}) async {
    try {
      final doc = await _firestore.collection(collectionName).doc(orderId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final double finalAmount = (data['finalAmount'] ?? 0.0).toDouble();
        final double prevPaid = previousPaidAmount ?? (data['paidAmount'] ?? 0.0).toDouble();
        // Store actual remaining (can be negative to indicate overpayment/change due to customer)
        final double remaining = finalAmount - paidAmount;

        // Calculate the incremental payment made this time
        final double incrementalPayment = paidAmount - prevPaid;

        final Map<String, dynamic> updateData = {
          'paidAmount': paidAmount,
          'remainingAmount': remaining,
          'paymentStatus': paymentStatus,
        };

        // Only log to history when money is actually being added or a reversal happens
        if (incrementalPayment != 0) {
          final historyEntry = {
            'amount': incrementalPayment,
            'date': Timestamp.fromDate(DateTime.now()),
            'note': paymentStatus == 'Pending' ? 'Marked Unpaid' : (paymentNote ?? (incrementalPayment > 0 ? 'Payment received' : 'Payment reversed')),
          };
          updateData['paymentHistory'] = FieldValue.arrayUnion([historyEntry]);
        }

        await _firestore.collection(collectionName).doc(orderId).update(updateData);
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

      // Sync Customer metrics on update!
      await _updateCustomerOnOrderUpdated(oldOrder, newOrder);

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
      
      // Sync Customer metrics on delete!
      await _updateCustomerOnOrderDeleted(order);

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

  // --- Customer Directory Auto-Sync Helpers ---

  Future<void> _updateCustomerOnOrderCreated(OrderModel order) async {
    if (order.isSupplyOrder) return;
    
    final String shopName = order.shopName.trim();
    if (shopName.isEmpty) return;

    final customersRef = _firestore.collection('customers');
    final querySnapshot = await customersRef.get();
    
    CustomerModel? matchedCustomer;
    for (var doc in querySnapshot.docs) {
      final c = CustomerModel.fromMap(doc.data(), doc.id);
      
      int matchCount = 0;
      if (c.shopName.toLowerCase().trim() == shopName.toLowerCase()) {
        matchCount++;
      }
      if (c.mobileNumber.trim().isNotEmpty && order.customerMobile.trim().isNotEmpty &&
          c.mobileNumber.trim() == order.customerMobile.trim()) {
        matchCount++;
      }
      if (c.address.toLowerCase().trim().isNotEmpty && order.customerAddress.toLowerCase().trim().isNotEmpty &&
          c.address.toLowerCase().trim() == order.customerAddress.toLowerCase().trim()) {
        matchCount++;
      }
      
      if (matchCount >= 2) {
        matchedCustomer = c;
        break;
      }
    }

    if (matchedCustomer != null) {
      // Always use the order's non-empty value so updated details (e.g. new GST) are persisted.
      final String updatedAddress = order.customerAddress.trim().isNotEmpty ? order.customerAddress.trim() : matchedCustomer.address;
      final String updatedGst    = order.customerGstNumber.trim().isNotEmpty && order.customerGstNumber.trim() != 'URP'
          ? order.customerGstNumber.trim() : matchedCustomer.gstNumber;
      final String updatedMobile = order.customerMobile.trim().isNotEmpty ? order.customerMobile.trim() : matchedCustomer.mobileNumber;
      final String updatedPartner = matchedCustomer.partnerId.trim().isEmpty 
          ? (order.referredPartnerId.isNotEmpty ? order.referredPartnerId : order.createdBy) 
          : matchedCustomer.partnerId;

      await customersRef.doc(matchedCustomer.id).update({
        'address': updatedAddress,
        'gstNumber': updatedGst,
        'mobileNumber': updatedMobile,
        'partnerId': updatedPartner,
        'totalOrders': matchedCustomer.totalOrders + 1,
        'totalAmountSpent': matchedCustomer.totalAmountSpent + order.finalAmount,
      });
    } else {
      final newId = customersRef.doc().id;
      final String partner = order.referredPartnerId.isNotEmpty 
          ? order.referredPartnerId 
          : (order.createdBy.isNotEmpty ? order.createdBy : 'admin');
          
      final newCustomer = CustomerModel(
        id: newId,
        shopName: shopName,
        mobileNumber: order.customerMobile.trim(),
        address: order.customerAddress.trim(),
        gstNumber: order.customerGstNumber.trim(),
        partnerId: partner,
        totalOrders: 1,
        totalAmountSpent: order.finalAmount,
        createdAt: order.createdAt,
      );
      
      await customersRef.doc(newId).set(newCustomer.toMap());
    }
  }

  Future<void> _updateCustomerOnOrderUpdated(OrderModel oldOrder, OrderModel newOrder) async {
    if (oldOrder.isSupplyOrder && newOrder.isSupplyOrder) return;

    final customersRef = _firestore.collection('customers');
    final querySnapshot = await customersRef.get();
    final List<CustomerModel> allCustomers = querySnapshot.docs
        .map((doc) => CustomerModel.fromMap(doc.data(), doc.id))
        .toList();
        
    CustomerModel? oldCustomer;
    if (!oldOrder.isSupplyOrder && oldOrder.shopName.trim().isNotEmpty) {
      for (var c in allCustomers) {
        int matchCount = 0;
        if (c.shopName.toLowerCase().trim() == oldOrder.shopName.toLowerCase().trim()) {
          matchCount++;
        }
        if (c.mobileNumber.trim().isNotEmpty && oldOrder.customerMobile.trim().isNotEmpty &&
            c.mobileNumber.trim() == oldOrder.customerMobile.trim()) {
          matchCount++;
        }
        if (c.address.toLowerCase().trim().isNotEmpty && oldOrder.customerAddress.toLowerCase().trim().isNotEmpty &&
            c.address.toLowerCase().trim() == oldOrder.customerAddress.toLowerCase().trim()) {
          matchCount++;
        }
        if (matchCount >= 2) {
          oldCustomer = c;
          break;
        }
      }
    }

    CustomerModel? newCustomer;
    if (!newOrder.isSupplyOrder && newOrder.shopName.trim().isNotEmpty) {
      for (var c in allCustomers) {
        int matchCount = 0;
        if (c.shopName.toLowerCase().trim() == newOrder.shopName.toLowerCase().trim()) {
          matchCount++;
        }
        if (c.mobileNumber.trim().isNotEmpty && newOrder.customerMobile.trim().isNotEmpty &&
            c.mobileNumber.trim() == newOrder.customerMobile.trim()) {
          matchCount++;
        }
        if (c.address.toLowerCase().trim().isNotEmpty && newOrder.customerAddress.toLowerCase().trim().isNotEmpty &&
            c.address.toLowerCase().trim() == newOrder.customerAddress.toLowerCase().trim()) {
          matchCount++;
        }
        if (matchCount >= 2) {
          newCustomer = c;
          break;
        }
      }
    }

    if (oldCustomer != null && newCustomer != null && oldCustomer.id == newCustomer.id) {
      final double amountDelta = newOrder.finalAmount - oldOrder.finalAmount;
      // Always use the order's non-empty value so updated details are persisted.
      final String updatedAddress = newOrder.customerAddress.trim().isNotEmpty ? newOrder.customerAddress.trim() : oldCustomer.address;
      final String updatedGst    = newOrder.customerGstNumber.trim().isNotEmpty && newOrder.customerGstNumber.trim() != 'URP'
          ? newOrder.customerGstNumber.trim() : oldCustomer.gstNumber;
      final String updatedMobile = newOrder.customerMobile.trim().isNotEmpty ? newOrder.customerMobile.trim() : oldCustomer.mobileNumber;
      await customersRef.doc(oldCustomer.id).update({
        'totalAmountSpent': oldCustomer.totalAmountSpent + amountDelta,
        'address': updatedAddress,
        'gstNumber': updatedGst,
        'mobileNumber': updatedMobile,
      });
    } else {
      if (oldCustomer != null) {
        final int updatedOrders = (oldCustomer.totalOrders - 1).clamp(0, 999999);
        final double updatedAmount = (oldCustomer.totalAmountSpent - oldOrder.finalAmount).clamp(0.0, double.infinity);
        await customersRef.doc(oldCustomer.id).update({
          'totalOrders': updatedOrders,
          'totalAmountSpent': updatedAmount,
        });
      }
      
      if (newCustomer != null) {
        // Always use the order's non-empty value so updated details are persisted.
        final String updatedAddress = newOrder.customerAddress.trim().isNotEmpty ? newOrder.customerAddress.trim() : newCustomer.address;
        final String updatedGst    = newOrder.customerGstNumber.trim().isNotEmpty && newOrder.customerGstNumber.trim() != 'URP'
            ? newOrder.customerGstNumber.trim() : newCustomer.gstNumber;
        final String updatedMobile = newOrder.customerMobile.trim().isNotEmpty ? newOrder.customerMobile.trim() : newCustomer.mobileNumber;
        final String updatedPartner = newCustomer.partnerId.trim().isEmpty 
            ? (newOrder.referredPartnerId.isNotEmpty ? newOrder.referredPartnerId : newOrder.createdBy) 
            : newCustomer.partnerId;

        await customersRef.doc(newCustomer.id).update({
          'address': updatedAddress,
          'gstNumber': updatedGst,
          'mobileNumber': updatedMobile,
          'partnerId': updatedPartner,
          'totalOrders': newCustomer.totalOrders + 1,
          'totalAmountSpent': newCustomer.totalAmountSpent + newOrder.finalAmount,
        });
      } else if (!newOrder.isSupplyOrder && newOrder.shopName.trim().isNotEmpty) {
        final newId = customersRef.doc().id;
        final String partner = newOrder.referredPartnerId.isNotEmpty 
            ? newOrder.referredPartnerId 
            : (newOrder.createdBy.isNotEmpty ? newOrder.createdBy : 'admin');
            
        final brandNewCustomer = CustomerModel(
          id: newId,
          shopName: newOrder.shopName.trim(),
          mobileNumber: newOrder.customerMobile.trim(),
          address: newOrder.customerAddress.trim(),
          gstNumber: newOrder.customerGstNumber.trim(),
          partnerId: partner,
          totalOrders: 1,
          totalAmountSpent: newOrder.finalAmount,
          createdAt: newOrder.createdAt,
        );
        await customersRef.doc(newId).set(brandNewCustomer.toMap());
      }
    }
  }

  Future<void> _updateCustomerOnOrderDeleted(OrderModel order) async {
    if (order.isSupplyOrder) return;
    
    final String shopName = order.shopName.trim();
    if (shopName.isEmpty) return;

    final customersRef = _firestore.collection('customers');
    final querySnapshot = await customersRef.get();
    
    CustomerModel? matchedCustomer;
    for (var doc in querySnapshot.docs) {
      final c = CustomerModel.fromMap(doc.data(), doc.id);
      
      int matchCount = 0;
      if (c.shopName.toLowerCase().trim() == shopName.toLowerCase()) {
        matchCount++;
      }
      if (c.mobileNumber.trim().isNotEmpty && order.customerMobile.trim().isNotEmpty &&
          c.mobileNumber.trim() == order.customerMobile.trim()) {
        matchCount++;
      }
      if (c.address.toLowerCase().trim().isNotEmpty && order.customerAddress.toLowerCase().trim().isNotEmpty &&
          c.address.toLowerCase().trim() == order.customerAddress.toLowerCase().trim()) {
        matchCount++;
      }
      
      if (matchCount >= 2) {
        matchedCustomer = c;
        break;
      }
    }

    if (matchedCustomer != null) {
      final int updatedOrders = (matchedCustomer.totalOrders - 1).clamp(0, 999999);
      final double updatedAmount = (matchedCustomer.totalAmountSpent - order.finalAmount).clamp(0.0, double.infinity);
      
      await customersRef.doc(matchedCustomer.id).update({
        'totalOrders': updatedOrders,
        'totalAmountSpent': updatedAmount,
      });
    }
  }
}
