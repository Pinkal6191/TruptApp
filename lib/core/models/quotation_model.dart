import 'package:cloud_firestore/cloud_firestore.dart';

class QuotationItemModel {
  final String productName;
  final int quantity;
  final double pricePerUnit;
  final String unitType; // 'Crates', 'Bottles', 'Boxes', 'Units'

  QuotationItemModel({
    required this.productName,
    required this.quantity,
    required this.pricePerUnit,
    required this.unitType,
  });

  factory QuotationItemModel.fromMap(Map<String, dynamic> map) {
    return QuotationItemModel(
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] ?? 0).toInt(),
      pricePerUnit: (map['pricePerUnit'] ?? 0.0).toDouble(),
      unitType: map['unitType'] ?? 'Crates',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
      'unitType': unitType,
    };
  }
}

class QuotationModel {
  final String id;
  final String quotationNumber;
  final String shopName;
  final String contactPerson;
  final String customerMobile;
  final String customerAddress;
  final DateTime createdAt;
  final DateTime validUntil;
  final String quotationType; // 'Custom Branding', 'Regular Bottle', 'Distributor Supply'
  final List<QuotationItemModel> items;
  final double subtotal;
  final double gstAmount;
  final double finalAmount;
  final bool withGst;
  final String termsConditions;

  QuotationModel({
    required this.id,
    required this.quotationNumber,
    required this.shopName,
    required this.contactPerson,
    required this.customerMobile,
    required this.customerAddress,
    required this.createdAt,
    required this.validUntil,
    required this.quotationType,
    required this.items,
    required this.subtotal,
    required this.gstAmount,
    required this.finalAmount,
    required this.withGst,
    this.termsConditions = '',
  });

  factory QuotationModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Parse timestamps
    DateTime created = DateTime.now();
    if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        created = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        created = DateTime.parse(data['createdAt']);
      }
    }

    DateTime valid = DateTime.now().add(const Duration(days: 30));
    if (data['validUntil'] != null) {
      if (data['validUntil'] is Timestamp) {
        valid = (data['validUntil'] as Timestamp).toDate();
      } else if (data['validUntil'] is String) {
        valid = DateTime.parse(data['validUntil']);
      }
    }

    // Parse items list
    List<QuotationItemModel> itemsList = [];
    if (data['items'] != null) {
      itemsList = (data['items'] as List)
          .map((item) => QuotationItemModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    return QuotationModel(
      id: doc.id,
      quotationNumber: data['quotationNumber'] ?? '',
      shopName: data['shopName'] ?? '',
      contactPerson: data['contactPerson'] ?? '',
      customerMobile: data['customerMobile'] ?? '',
      customerAddress: data['customerAddress'] ?? '',
      createdAt: created,
      validUntil: valid,
      quotationType: data['quotationType'] ?? 'Regular Bottle',
      items: itemsList,
      subtotal: (data['subtotal'] ?? 0.0).toDouble(),
      gstAmount: (data['gstAmount'] ?? 0.0).toDouble(),
      finalAmount: (data['finalAmount'] ?? 0.0).toDouble(),
      withGst: data['withGst'] ?? true,
      termsConditions: data['termsConditions'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quotationNumber': quotationNumber,
      'shopName': shopName,
      'contactPerson': contactPerson,
      'customerMobile': customerMobile,
      'customerAddress': customerAddress,
      'createdAt': Timestamp.fromDate(createdAt),
      'validUntil': Timestamp.fromDate(validUntil),
      'quotationType': quotationType,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'gstAmount': gstAmount,
      'finalAmount': finalAmount,
      'withGst': withGst,
      'termsConditions': termsConditions,
    };
  }
}
