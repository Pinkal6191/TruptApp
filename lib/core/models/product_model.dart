import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final int bottlesPerCrate;
  final double retailPrice;
  final double distributorPrice;
  final List<Map<String, dynamic>> recipe; // [{materialId, quantityPerCrate}]

  ProductModel({
    required this.id,
    required this.name,
    required this.bottlesPerCrate,
    required this.retailPrice,
    required this.distributorPrice,
    this.recipe = const [],
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      bottlesPerCrate: (data['bottlesPerCrate'] ?? 0).toInt(),
      retailPrice: (data['retailPrice'] ?? 0).toDouble(),
      distributorPrice: (data['distributorPrice'] ?? 0).toDouble(),
      recipe: List<Map<String, dynamic>>.from(data['recipe'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'bottlesPerCrate': bottlesPerCrate,
      'retailPrice': retailPrice,
      'distributorPrice': distributorPrice,
      'recipe': recipe,
    };
  }
}
