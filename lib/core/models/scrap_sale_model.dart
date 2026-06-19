import 'package:cloud_firestore/cloud_firestore.dart';

class ScrapSaleModel {
  final String id;
  final String buyerName;
  final double weightKg;
  final double amount;
  final DateTime date;
  final String description;

  ScrapSaleModel({
    required this.id,
    required this.buyerName,
    required this.weightKg,
    required this.amount,
    required this.date,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'buyerName': buyerName,
      'weightKg': weightKg,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'description': description,
    };
  }

  factory ScrapSaleModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
    return ScrapSaleModel(
      id: doc.id,
      buyerName: map['buyerName'] ?? 'Unknown',
      weightKg: (map['weightKg'] ?? 0.0).toDouble(),
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'] ?? '',
    );
  }
}
