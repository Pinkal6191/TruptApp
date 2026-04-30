import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/product_model.dart';

class ProductRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'products';

  Future<List<ProductModel>> getProducts() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(collectionName).get();
      return snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to load products: $e');
    }
  }

  Future<void> addProduct(ProductModel product) async {
    try {
      await _firestore.collection(collectionName).add(product.toMap());
    } catch (e) {
      throw Exception('Failed to add product: $e');
    }
  }

  // Initial seed method
  Future<void> seedInitialProducts() async {
    try {
      QuerySnapshot existing = await _firestore.collection(collectionName).limit(1).get();
      if (existing.docs.isEmpty) {
        List<Map<String, dynamic>> initialProducts = [
          {'name': '200ml', 'defaultPrice': 5.0},
          {'name': '500ml', 'defaultPrice': 10.0},
          {'name': '1L', 'defaultPrice': 20.0},
        ];

        for (var p in initialProducts) {
          await _firestore.collection(collectionName).add(p);
        }
      }
    } catch (e) {
      throw Exception('Failed to seed products: $e');
    }
  }
}
