class InventoryModel {
  final String productId;
  final String productName;
  final int stockCount; // Total crates in hand

  InventoryModel({
    required this.productId,
    required this.productName,
    required this.stockCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'stockCount': stockCount,
    };
  }

  factory InventoryModel.fromMap(Map<String, dynamic> map) {
    return InventoryModel(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      stockCount: (map['stockCount'] ?? 0).toInt(),
    );
  }
}
