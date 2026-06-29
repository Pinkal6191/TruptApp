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
  final String orderType; // 'standard' or 'private_label'
  final List<OrderItemModel> items;
  final double subtotal;
  final double gstAmount; // E.g. 18%
  final double discount;
  final double finalAmount;
  final String deliveryStatus; // "Pending", "Dispatched", "Delivered"
  final String paymentStatus; // "Pending", "Partial", "Paid"
  final double paidAmount;
  final DateTime createdAt;
  final String orderReference; // 'Direct (Online / Call)' or Partner's name
  final String additionalNote;
  final double remainingAmount;
  final String referredPartnerId;
  final List<Map<String, dynamic>> paymentHistory; // [{amount, date, note}]

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
    this.orderType = 'standard',
    required this.items,
    required this.subtotal,
    required this.gstAmount,
    required this.discount,
    required this.finalAmount,
    this.deliveryStatus = 'Pending',
    this.paymentStatus = 'Pending',
    this.paidAmount = 0.0,
    required this.createdAt,
    this.orderReference = 'Direct (Online / Call)',
    this.additionalNote = '',
    this.referredPartnerId = '',
    List<Map<String, dynamic>>? paymentHistory,
    double? remainingAmount,
  }) : this.remainingAmount = remainingAmount ?? (finalAmount - paidAmount),
       this.paymentHistory = paymentHistory ?? [];

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
      'orderType': orderType,
      'items': items.map((x) => x.toMap()).toList(),
      'subtotal': subtotal,
      'gstAmount': gstAmount,
      'discount': discount,
      'finalAmount': finalAmount,
      'deliveryStatus': deliveryStatus,
      'paymentStatus': paymentStatus,
      'paidAmount': paidAmount,
      'remainingAmount': remainingAmount,
      'createdAt': Timestamp.fromDate(createdAt),
      'orderReference': orderReference,
      'additionalNote': additionalNote,
      'referredPartnerId': referredPartnerId,
      'paymentHistory': paymentHistory,
    };
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
    double finalAmt = (map['finalAmount'] ?? 0).toDouble();
    double paidAmt = (map['paidAmount'] ?? 0).toDouble();
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
      orderType: map['orderType'] ?? 'standard',
      items: List<OrderItemModel>.from(
        (map['items'] ?? []).map((x) => OrderItemModel.fromMap(x)),
      ),
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      gstAmount: (map['gstAmount'] ?? 0).toDouble(),
      discount: (map['discount'] ?? 0).toDouble(),
      finalAmount: finalAmt,
      deliveryStatus: map['deliveryStatus'] ?? 'Pending',
      paymentStatus: map['paymentStatus'] ?? 'Pending',
      paidAmount: paidAmt,
      remainingAmount: (map['remainingAmount'] ?? (finalAmt - paidAmt)).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      orderReference: map['orderReference'] ?? 'Direct (Online / Call)',
      additionalNote: map['additionalNote'] ?? '',
      referredPartnerId: map['referredPartnerId'] ?? '',
      paymentHistory: List<Map<String, dynamic>>.from(
        (map['paymentHistory'] ?? []).map((e) {
          final m = Map<String, dynamic>.from(e);
          if (!m.containsKey('paymentMethod')) {
            m['paymentMethod'] = 'Cash';
          }
          return m;
        }),
      ),
    );
  }

  double getFilteredPaidAmount(String method) {
    if (method == 'All') return paidAmount;
    double sum = 0.0;
    if (paymentHistory.isEmpty) {
      if (method == 'Cash') {
        return paidAmount;
      }
      return 0.0;
    }
    for (var entry in paymentHistory) {
      final String entryMethod = entry['paymentMethod'] ?? 'Cash';
      if (entryMethod.toLowerCase() == method.toLowerCase()) {
        sum += (entry['amount'] as num).toDouble();
      }
    }
    return sum;
  }

  List<String> getPaymentMethods() {
    if (paymentHistory.isEmpty) {
      return paidAmount > 0 ? ['Cash'] : [];
    }
    final Set<String> methods = {};
    for (var entry in paymentHistory) {
      final String entryMethod = entry['paymentMethod'] ?? 'Cash';
      methods.add(entryMethod);
    }
    return methods.toList();
  }
}
