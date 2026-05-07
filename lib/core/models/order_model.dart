import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_item_model.dart';

class OrderModel {
  final String id;
  final String createdBy; // User UID
  final String targetUserId; // UID of the receiver (if Admin supply) or customer
  final String partnerName;
  final String shopName;
  final String customerMobile;
  final String customerAddress;
  final String customerGstNumber;
  final String invoiceNumber;
  final String creatorRole; // 'admin', 'partner', 'distributor'
  final bool isInclusiveGST;
  final bool isSupplyOrder; // True if Admin is supplying to Distributor
  final List<OrderItemModel> items;
  final double subtotal;
  final double gstAmount; // E.g. 18%
  final double discount;
  final double finalAmount;
  final String deliveryStatus; // "Pending", "Dispatched", "Delivered"
  final String paymentStatus; // "Pending", "Partial", "Paid"
  final double paidAmount;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.createdBy,
    required this.targetUserId,
    required this.partnerName,
    required this.shopName,
    required this.customerMobile,
    this.customerAddress = '',
    this.customerGstNumber = '',
    this.invoiceNumber = '',
    required this.creatorRole,
    this.isInclusiveGST = true,
    this.isSupplyOrder = false,
    required this.items,
    required this.subtotal,
    required this.gstAmount,
    required this.discount,
    required this.finalAmount,
    this.deliveryStatus = 'Pending',
    this.paymentStatus = 'Pending',
    this.paidAmount = 0.0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'createdBy': createdBy,
      'targetUserId': targetUserId,
      'partnerName': partnerName,
      'shopName': shopName,
      'customerMobile': customerMobile,
      'customerAddress': customerAddress,
      'customerGstNumber': customerGstNumber,
      'invoiceNumber': invoiceNumber,
      'creatorRole': creatorRole,
      'isInclusiveGST': isInclusiveGST,
      'isSupplyOrder': isSupplyOrder,
      'items': items.map((x) => x.toMap()).toList(),
      'subtotal': subtotal,
      'gstAmount': gstAmount,
      'discount': discount,
      'finalAmount': finalAmount,
      'deliveryStatus': deliveryStatus,
      'paymentStatus': paymentStatus,
      'paidAmount': paidAmount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      createdBy: map['createdBy'] ?? '',
      targetUserId: map['targetUserId'] ?? '',
      partnerName: map['partnerName'] ?? 'Unknown Partner',
      shopName: map['shopName'] ?? '',
      customerMobile: map['customerMobile'] ?? '',
      customerAddress: map['customerAddress'] ?? '',
      customerGstNumber: map['customerGstNumber'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      creatorRole: map['creatorRole'] ?? 'partner',
      isInclusiveGST: map['isInclusiveGST'] ?? true,
      isSupplyOrder: map['isSupplyOrder'] ?? false,
      items: List<OrderItemModel>.from(
        (map['items'] ?? []).map((x) => OrderItemModel.fromMap(x)),
      ),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      gstAmount: (map['gstAmount'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      finalAmount: (map['finalAmount'] ?? 0).toDouble(),
      deliveryStatus: map['deliveryStatus'] ?? 'Pending',
      paymentStatus: map['paymentStatus'] ?? 'Pending',
      paidAmount: (map['paidAmount'] ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
