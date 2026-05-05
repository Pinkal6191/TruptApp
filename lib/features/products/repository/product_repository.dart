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

  Future<void> updateProduct(ProductModel product) async {
    try {
      await _firestore.collection(collectionName).doc(product.id).update(product.toMap());
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection(collectionName).doc(productId).delete();
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  // Initial seed method
  Future<void> seedInitialProducts() async {
    try {
      QuerySnapshot existing = await _firestore.collection(collectionName).limit(1).get();
      if (existing.docs.isEmpty) {
        List<Map<String, dynamic>> initialProducts = [
          {
            'name': '200ml',
            'bottlesPerCrate': 30,
            'retailPrice': 100.0,
            'distributorPrice': 100.0
          },
          {
            'name': '500ml',
            'bottlesPerCrate': 24,
            'retailPrice': 105.0,
            'distributorPrice': 95.0
          },
          {
            'name': '1L',
            'bottlesPerCrate': 12,
            'retailPrice': 90.0,
            'distributorPrice': 80.0
          },
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
