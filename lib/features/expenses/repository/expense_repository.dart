import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/expense_model.dart';

class ExpenseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'expenses';

  Future<void> addExpense(ExpenseModel expense) async {
    try {
      await _firestore.collection(collectionName).add(expense.toMap());
    } catch (e) {
      throw Exception('Failed to add expense: $e');
    }
  }

  Future<List<ExpenseModel>> getExpenses() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(collectionName)
          .orderBy('date', descending: true)
          .get();
      return snapshot.docs.map((doc) => ExpenseModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get expenses: $e');
    }
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    try {
      await _firestore.collection(collectionName).doc(expense.id).update(expense.toMap());
    } catch (e) {
      throw Exception('Failed to update expense: $e');
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await _firestore.collection(collectionName).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete expense: $e');
    }
  }
}
