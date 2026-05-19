class CustomerModel {
  final String id;
  final String shopName;
  final String mobileNumber;
  final String address;
  final String gstNumber;
  final String partnerId; // ID of the partner who created/owns this customer
  final int totalOrders;
  final double totalAmountSpent;
  final DateTime createdAt;

  CustomerModel({
    required this.id,
    required this.shopName,
    required this.mobileNumber,
    required this.address,
    required this.gstNumber,
    required this.partnerId,
    this.totalOrders = 0,
    this.totalAmountSpent = 0.0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shopName': shopName,
      'mobileNumber': mobileNumber,
      'address': address,
      'gstNumber': gstNumber,
      'partnerId': partnerId,
      'totalOrders': totalOrders,
      'totalAmountSpent': totalAmountSpent,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map, String docId) {
    return CustomerModel(
      id: docId,
      shopName: map['shopName'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      address: map['address'] ?? '',
      gstNumber: map['gstNumber'] ?? '',
      partnerId: map['partnerId'] ?? '',
      totalOrders: map['totalOrders'] ?? 0,
      totalAmountSpent: (map['totalAmountSpent'] ?? 0).toDouble(),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }
}
