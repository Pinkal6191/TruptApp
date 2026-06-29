import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/raw_material_model.dart';
import '../../../core/models/production_log_model.dart';

class ProductionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all raw materials
  Stream<List<RawMaterialModel>> watchRawMaterials() {
    return _firestore.collection('raw_materials').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RawMaterialModel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  // Add raw material
  Future<void> addRawMaterial(
    RawMaterialModel material, {
    double? purchaseCost,
    double? transportCost,
    String? userId,
    String? userName,
  }) async {
    try {
      final docRef = _firestore.collection('raw_materials').doc();
      await _firestore.runTransaction((transaction) async {
        transaction.set(docRef, material.toMap());

        if (material.stockCount > 0) {
          final double totalCost = (purchaseCost ?? 0.0) + (transportCost ?? 0.0);
          final double perUnit = totalCost / material.stockCount;

          final adjustmentRef = docRef.collection('adjustments').doc();
          transaction.set(adjustmentRef, {
            'adjustment': material.stockCount,
            'previousStock': 0.0,
            'newStock': material.stockCount,
            'purchaseCost': purchaseCost ?? 0.0,
            'transportCost': transportCost ?? 0.0,
            'perUnitCost': perUnit,
            'action': 'Initial Creation',
            'date': Timestamp.fromDate(DateTime.now()),
            'userId': userId ?? '',
            'userName': userName ?? '',
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to add raw material: $e');
    }
  }

  // Update raw material details
  Future<void> updateRawMaterial(RawMaterialModel material) async {
    try {
      await _firestore.collection('raw_materials').doc(material.id).update(material.toMap());
    } catch (e) {
      throw Exception('Failed to update raw material: $e');
    }
  }

  // Manually adjust raw material stock
  Future<void> updateRawMaterialStock(
    String materialId,
    double adjustment, {
    double? purchaseCost,
    double? transportCost,
    String? userId,
    String? userName,
  }) async {
    try {
      final docRef = _firestore.collection('raw_materials').doc(materialId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          double currentStock = (snapshot.data()?['stockCount'] ?? 0.0).toDouble();
          double newStock = currentStock + adjustment;
          transaction.update(docRef, {'stockCount': newStock});

          final double totalCost = (purchaseCost ?? 0.0) + (transportCost ?? 0.0);
          final double perUnit = (adjustment > 0 && totalCost > 0) ? (totalCost / adjustment) : 0.0;

          final adjustmentRef = docRef.collection('adjustments').doc();
          transaction.set(adjustmentRef, {
            'adjustment': adjustment,
            'previousStock': currentStock,
            'newStock': newStock,
            'purchaseCost': purchaseCost ?? 0.0,
            'transportCost': transportCost ?? 0.0,
            'perUnitCost': perUnit,
            'action': adjustment > 0 ? 'Add Stock' : 'Consume',
            'date': Timestamp.fromDate(DateTime.now()),
            'userId': userId ?? '',
            'userName': userName ?? '',
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to adjust raw material stock: $e');
    }
  }

  // Delete raw material
  Future<void> deleteRawMaterial(String materialId) async {
    try {
      await _firestore.collection('raw_materials').doc(materialId).delete();
    } catch (e) {
      throw Exception('Failed to delete raw material: $e');
    }
  }

  // Stream production logs sorted by date descending
  Stream<List<ProductionLogModel>> watchProductionLogs() {
    return _firestore
        .collection('production_logs')
        .snapshots()
        .map((snapshot) {
      final logs = snapshot.docs
          .map((doc) => ProductionLogModel.fromFirestore(doc.id, doc.data()))
          .toList();
      logs.sort((a, b) => b.date.compareTo(a.date));
      return logs;
    });
  }

  // Stream factory ready finished goods inventory
  Stream<List<Map<String, dynamic>>> watchFactoryInventory() {
    return _firestore.collection('factory_inventory').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'productId': doc.id,
          'productName': data['productName'] ?? '',
          'stockCount': (data['stockCount'] ?? 0).toInt(),
        };
      }).toList();
    });
  }

  // Log a production run transactionally
  Future<void> logProductionRun(ProductionLogModel log) async {
    try {
      final factoryStockRef = _firestore.collection('factory_inventory').doc(log.productId);

      await _firestore.runTransaction((transaction) async {
        // 1. Save the production log doc
        final logRef = _firestore.collection('production_logs').doc();
        transaction.set(logRef, log.toMap());

        // 2. Increment Factory Finished goods inventory
        final factoryStockSnapshot = await transaction.get(factoryStockRef);
        if (factoryStockSnapshot.exists) {
          int currentStock = (factoryStockSnapshot.data()?['stockCount'] ?? 0).toInt();
          transaction.update(factoryStockRef, {'stockCount': currentStock + log.cratesProduced});
        } else {
          transaction.set(factoryStockRef, {
            'productId': log.productId,
            'productName': log.productName,
            'stockCount': log.cratesProduced,
          });
        }

        // 3. Decrement consumed raw materials and log history
        for (var consumed in log.consumedMaterials) {
          final String matId = consumed['materialId'] ?? '';
          final double qty = (consumed['quantity'] ?? 0.0).toDouble();

          if (matId.isNotEmpty) {
            final matRef = _firestore.collection('raw_materials').doc(matId);
            final matSnapshot = await transaction.get(matRef);
            if (matSnapshot.exists) {
              double currentStock = (matSnapshot.data()?['stockCount'] ?? 0.0).toDouble();
              double newStock = currentStock - qty;
              transaction.update(matRef, {'stockCount': newStock});

              final adjustmentRef = matRef.collection('adjustments').doc();
              transaction.set(adjustmentRef, {
                'adjustment': -qty,
                'previousStock': currentStock,
                'newStock': newStock,
                'purchaseCost': 0.0,
                'transportCost': 0.0,
                'perUnitCost': 0.0,
                'action': 'Production Consumption',
                'date': Timestamp.fromDate(DateTime.now()),
                'userId': '',
                'userName': 'Production Run',
              });
            }
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to log production run: $e');
    }
  }

  // Manually adjust factory stock level
  Future<void> updateFactoryStock(String productId, String productName, int adjustment) async {
    try {
      final docRef = _firestore.collection('factory_inventory').doc(productId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          int currentStock = (snapshot.data()?['stockCount'] ?? 0).toInt();
          transaction.update(docRef, {'stockCount': currentStock + adjustment});
        } else {
          transaction.set(docRef, {
            'productId': productId,
            'productName': productName,
            'stockCount': adjustment,
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to adjust factory stock: $e');
    }
  }

  // Stream raw material stock adjustment logs descending by date
  Stream<List<Map<String, dynamic>>> watchRawMaterialAdjustments(String materialId) {
    return _firestore
        .collection('raw_materials')
        .doc(materialId)
        .collection('adjustments')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
              };
            }).toList());
  }
}
