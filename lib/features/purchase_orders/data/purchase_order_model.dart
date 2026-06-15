import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseOrderItemModel {
  final String partNumber;
  final String description;
  final String uom;
  final double specialPrice;
  final double quantity;
  final String hsnCode;
  final double igstRate; // in percentage, e.g., 18.0

  PurchaseOrderItemModel({
    required this.partNumber,
    required this.description,
    required this.uom,
    required this.specialPrice,
    required this.quantity,
    required this.hsnCode,
    required this.igstRate,
  });

  Map<String, dynamic> toMap() {
    return {
      'partNumber': partNumber,
      'description': description,
      'uom': uom,
      'specialPrice': specialPrice,
      'quantity': quantity,
      'hsnCode': hsnCode,
      'igstRate': igstRate,
    };
  }

  factory PurchaseOrderItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItemModel(
      partNumber: map['partNumber'] ?? '',
      description: map['description'] ?? '',
      uom: map['uom'] ?? '',
      specialPrice: (map['specialPrice'] ?? 0.0).toDouble(),
      quantity: (map['quantity'] ?? 0.0).toDouble(),
      hsnCode: map['hsnCode'] ?? '',
      igstRate: (map['igstRate'] ?? 0.0).toDouble(),
    );
  }

  double get totalPriceWithoutTax => specialPrice * quantity;
  double get taxAmount => totalPriceWithoutTax * (igstRate / 100);
  double get totalAmount => totalPriceWithoutTax + taxAmount;
}

class PurchaseOrderModel {
  final String id;
  final DateTime createdAt;
  final String poNumber;
  final String vendorName;
  final String vendorAddress;
  final String attentionName;
  final String contactNumber;
  final List<PurchaseOrderItemModel> items;
  final String paymentTerms;
  final String createdBy;

  PurchaseOrderModel({
    required this.id,
    required this.createdAt,
    required this.poNumber,
    required this.vendorName,
    required this.vendorAddress,
    required this.attentionName,
    required this.contactNumber,
    required this.items,
    required this.paymentTerms,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAt': Timestamp.fromDate(createdAt),
      'poNumber': poNumber,
      'vendorName': vendorName,
      'vendorAddress': vendorAddress,
      'attentionName': attentionName,
      'contactNumber': contactNumber,
      'items': items.map((x) => x.toMap()).toList(),
      'paymentTerms': paymentTerms,
      'createdBy': createdBy,
    };
  }

  factory PurchaseOrderModel.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderModel(
      id: map['id'] ?? '',
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
      poNumber: map['poNumber'] ?? '',
      vendorName: map['vendorName'] ?? '',
      vendorAddress: map['vendorAddress'] ?? '',
      attentionName: map['attentionName'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
      items: List<PurchaseOrderItemModel>.from(
        (map['items'] as List? ?? []).map((x) => PurchaseOrderItemModel.fromMap(x)),
      ),
      paymentTerms: map['paymentTerms'] ?? '',
      createdBy: map['createdBy'] ?? '',
    );
  }
}
