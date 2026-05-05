class OrderItemModel {
  final String productId;
  final String productName;
  final int quantity;
  final double pricePerCrate; 
  final double margin; // Legacy margin
  final double distributorCost; // Tracks the purchase price for accurate commission

  OrderItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.pricePerCrate,
    this.margin = 0.0,
    this.distributorCost = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'pricePerCrate': pricePerCrate,
      'margin': margin,
      'distributorCost': distributorCost,
    };
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] ?? 0).toInt(),
      pricePerCrate: (map['pricePerCrate'] ?? map['unitPrice'] ?? 0).toDouble(), // Support legacy unitPrice
      margin: (map['margin'] ?? 0).toDouble(),
      distributorCost: (map['distributorCost'] ?? 0).toDouble(),
    );
  }
}
