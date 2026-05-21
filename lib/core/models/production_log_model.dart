import 'package:cloud_firestore/cloud_firestore.dart';

class ProductionLogModel {
  final String id;
  final DateTime date;
  final String productId;
  final String productName;
  final int cratesProduced;
  final String notes;
  final List<Map<String, dynamic>> consumedMaterials; // [{materialId, name, quantity, unit}]

  ProductionLogModel({
    required this.id,
    required this.date,
    required this.productId,
    required this.productName,
    required this.cratesProduced,
    this.notes = '',
    required this.consumedMaterials,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'productId': productId,
      'productName': productName,
      'cratesProduced': cratesProduced,
      'notes': notes,
      'consumedMaterials': consumedMaterials,
    };
  }

  factory ProductionLogModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ProductionLogModel(
      id: id,
      date: (data['date'] as Timestamp).toDate(),
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      cratesProduced: (data['cratesProduced'] ?? 0).toInt(),
      notes: data['notes'] ?? '',
      consumedMaterials: List<Map<String, dynamic>>.from(data['consumedMaterials'] ?? []),
    );
  }
}
