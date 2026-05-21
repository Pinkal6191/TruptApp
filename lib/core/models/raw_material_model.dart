class RawMaterialModel {
  final String id;
  final String name;
  final String unit; // e.g. kg, liters, pcs, bags
  final double stockCount;
  final double minReorderLevel;

  RawMaterialModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.stockCount,
    required this.minReorderLevel,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'unit': unit,
      'stockCount': stockCount,
      'minReorderLevel': minReorderLevel,
    };
  }

  factory RawMaterialModel.fromFirestore(String id, Map<String, dynamic> data) {
    return RawMaterialModel(
      id: id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? '',
      stockCount: (data['stockCount'] ?? 0.0).toDouble(),
      minReorderLevel: (data['minReorderLevel'] ?? 0.0).toDouble(),
    );
  }
}
