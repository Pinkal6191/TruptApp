import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/customer_model.dart';

class CustomerRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveCustomer(CustomerModel customer) async {
    final query = await _firestore
        .collection('customers')
        .where('mobileNumber', isEqualTo: customer.mobileNumber)
        .limit(1)
        .get();
        
    if (query.docs.isNotEmpty) {
      final existingDoc = query.docs.first;
      // Merge/update existing customer info
      await existingDoc.reference.update(customer.toMap());
    } else {
      await _firestore.collection('customers').doc(customer.id).set(customer.toMap());
    }
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final snapshot = await _firestore.collection('customers').get();
    return snapshot.docs.map((doc) => CustomerModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<void> updateCustomerMetrics(String customerId, double newOrderAmount) async {
    final docRef = _firestore.collection('customers').doc(customerId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final currentOrders = snapshot.data()?['totalOrders'] ?? 0;
        final currentAmount = (snapshot.data()?['totalAmountSpent'] ?? 0).toDouble();
        
        transaction.update(docRef, {
          'totalOrders': currentOrders + 1,
          'totalAmountSpent': currentAmount + newOrderAmount,
        });
      }
    });
  }
}
