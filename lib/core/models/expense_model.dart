import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String type; // "Transport", "Labor", "Other", "Delivery", "Extra"
  final double amount;
  final DateTime date;
  final String description;
  final String? userId; // ID of the partner if it's a partner expense
  final String? userName; // Name of the partner
  final double? distanceKm; // If delivery, distance in KM
  final String status; // 'Pending', 'Approved', 'Rejected', 'Paid'

  ExpenseModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    this.userId,
    this.userName,
    this.distanceKm,
    this.status = 'Approved', // Defaults to Approved for backwards compatibility with existing general expenses
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'description': description,
      'userId': userId,
      'userName': userName,
      'distanceKm': distanceKm,
      'status': status,
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
      userId: map['userId'],
      userName: map['userName'],
      distanceKm: map['distanceKm'] != null ? (map['distanceKm'] as num).toDouble() : null,
      status: map['status'] ?? 'Approved',
    );
  }
}
