import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String type; // "Transport", "Labor", "Other"
  final double amount;
  final DateTime date;
  final String description;

  ExpenseModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'description': description,
    };
  }

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id: doc.id,
      type: map['type'] ?? 'Other',
      amount: (map['amount'] ?? 0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      description: map['description'] ?? '',
    );
  }
}
