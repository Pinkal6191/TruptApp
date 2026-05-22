import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/customer_model.dart';

class CustomerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveCustomer(CustomerModel customer) async {
    final String shopName = customer.shopName.trim();
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
      if (c.mobileNumber.trim().isNotEmpty && customer.mobileNumber.trim().isNotEmpty &&
          c.mobileNumber.trim() == customer.mobileNumber.trim()) {
        matchCount++;
      }
      if (c.address.toLowerCase().trim().isNotEmpty && customer.address.toLowerCase().trim().isNotEmpty &&
          c.address.toLowerCase().trim() == customer.address.toLowerCase().trim()) {
        matchCount++;
      }
      
      if (matchCount >= 2) {
        matchedCustomer = c;
        break;
      }
    }

    if (matchedCustomer != null) {
      // Merge/update existing customer info
      await customersRef.doc(matchedCustomer.id).update(customer.toMap());
    } else {
      await customersRef.doc(customer.id).set(customer.toMap());
    }
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final snapshot = await _firestore.collection('customers').get();
    return snapshot.docs.map((doc) => CustomerModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> updateCustomerMetrics(String customerId, double newOrderAmount, {int ordersDelta = 1}) async {
    final docRef = _firestore.collection('customers').doc(customerId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final currentOrders = snapshot.data()?['totalOrders'] ?? 0;
        final currentAmount = (snapshot.data()?['totalAmountSpent'] ?? 0).toDouble();
        
        transaction.update(docRef, {
          'totalOrders': currentOrders + ordersDelta,
          'totalAmountSpent': currentAmount + newOrderAmount,
        });
      }
    });
  }

  /// Updates a customer's contact/profile details (name, mobile, address, gst).
  /// Does NOT touch totalOrders or totalAmountSpent.
  Future<void> updateCustomer(CustomerModel customer) async {
    await _firestore.collection('customers').doc(customer.id).update({
      'shopName': customer.shopName.trim(),
      'mobileNumber': customer.mobileNumber.trim(),
      'address': customer.address.trim(),
      'gstNumber': customer.gstNumber.trim(),
    });
  }

  /// Deletes a customer document entirely.
  Future<void> deleteCustomer(String customerId) async {
    await _firestore.collection('customers').doc(customerId).delete();
  }
}
