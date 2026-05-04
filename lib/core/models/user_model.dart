class UserModel {
  final String uid;
  final String name;
  final String mobile;
  final String role; // 'admin', 'partner', 'distributor'
  final String? gstNumber;
  final bool isApproved;

  UserModel({
    required this.uid,
    required this.name,
    required this.mobile,
    required this.role,
    this.gstNumber,
    this.isApproved = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      name: map['name'] ?? '',
      mobile: map['mobile'] ?? '',
      role: map['role'] ?? 'partner',
      gstNumber: map['gstNumber'],
      isApproved: map['isApproved'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'mobile': mobile,
      'role': role,
      'gstNumber': gstNumber,
      'isApproved': isApproved,
    };
  }
}
