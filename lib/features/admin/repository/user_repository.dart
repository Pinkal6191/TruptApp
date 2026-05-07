import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }

  Future<List<UserModel>> getDistributors() async {
    try {
      final snapshot = await _firestore.collection('users').where('role', isEqualTo: 'distributor').get();
      return snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      throw Exception('Failed to load distributors: $e');
    }
  }
  Future<void> updateCustomPrices(String userId, Map<String, double> customPrices) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'customPrices': customPrices,
      });
    } catch (e) {
      throw Exception('Failed to update custom prices: $e');
    }
  }

  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toMap());
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': isActive,
      });
    } catch (e) {
      throw Exception('Failed to toggle user status: $e');
    }
  }
}
