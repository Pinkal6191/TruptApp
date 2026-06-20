class UserModel {
  final String uid;
  final String name;
  final String mobile;
  final String role; // 'admin', 'partner', 'distributor', 'accountant'
  final String? gstNumber;
  final bool isApproved;
  final bool isActive;
  final Map<String, double> customPrices;

  UserModel({
    required this.uid,
    required this.name,
    required this.mobile,
    required this.role,
    this.gstNumber,
    this.isApproved = false,
    this.isActive = true,
    this.customPrices = const {},
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      role: map['role'] ?? 'partner',
      gstNumber: map['gstNumber'],
      isApproved: map['isApproved'] ?? false,
      isActive: map['isActive'] ?? true,
      customPrices: map['customPrices'] != null 
          ? Map<String, double>.from(map['customPrices'].map((key, value) => MapEntry(key, (value as num).toDouble())))
          : {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mobile': mobile,
      'role': role,
      'gstNumber': gstNumber,
      'isApproved': isApproved,
      'isActive': isActive,
      'customPrices': customPrices,
    };
  }
}
