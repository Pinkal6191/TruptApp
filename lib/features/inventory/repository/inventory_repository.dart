import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/inventory_model.dart';

class InventoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<InventoryModel>> getUserInventory(String userId) async {
    try {
      final snapshot = await _firestore.collection('users').doc(userId).collection('inventory').get();
      return snapshot.docs.map((doc) => InventoryModel.fromMap(doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to load inventory: $e');
    }
  }

  Stream<List<InventoryModel>> watchUserInventory(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('inventory')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => InventoryModel.fromMap(doc.data())).toList());
  }

  Future<void> updateStock(String userId, String productId, String productName, int adjustment) async {
    try {
      final docRef = _firestore.collection('users').doc(userId).collection('inventory').doc(productId);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        
        if (snapshot.exists) {
          int currentStock = (snapshot.data()?['stockCount'] ?? 0).toInt();
          transaction.update(docRef, {'stockCount': currentStock + adjustment});
        } else {
          transaction.set(docRef, {
            'productId': productId,
            'productName': productName,
            'stockCount': adjustment,
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to update stock: $e');
    }
  }
}
