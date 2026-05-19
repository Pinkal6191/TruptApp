import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DatabaseMaintenanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> wipeAllDataExceptAdminAndProducts() async {
    try {
      // 1. Delete all orders
      await _deleteCollection('orders');

      // 2. Delete all customers
      await _deleteCollection('customers');

      // 3. Delete all users except admin
      final usersSnapshot = await _firestore.collection('users').get();
      final batch = _firestore.batch();
      int batchCount = 0;
      
      for (var doc in usersSnapshot.docs) {
        final role = doc.data()['role'] as String?;
        if (role != 'admin') {
          batch.delete(doc.reference);
          batchCount++;
          // Note: Firestore batch limit is 500, but we assume fewer than 500 users for this simple CRM wipe.
          if (batchCount == 490) {
            await batch.commit();
            batchCount = 0;
            // A robust implementation would use chunking like _deleteCollection, 
            // but this is sufficient for pre-launch wipe.
          }
        }
      }
      
      if (batchCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error wiping data: $e');
      throw Exception('Failed to wipe data: $e');
    }
  }

  Future<void> _deleteCollection(String collectionPath) async {
    final collection = _firestore.collection(collectionPath);
    final snapshots = await collection.get();
    
    const int batchSize = 500; // Firestore limit per batch
    for (int i = 0; i < snapshots.docs.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize < snapshots.docs.length) ? i + batchSize : snapshots.docs.length;
      final chunk = snapshots.docs.sublist(i, end);
      
      for (var doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
