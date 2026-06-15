import 'package:cloud_firestore/cloud_firestore.dart';

class SystemSettingsModel {
  final double partnerDeliveryRatePerKm;

  SystemSettingsModel({
    this.partnerDeliveryRatePerKm = 10.0, // Default 10 rs/km
  });

  Map<String, dynamic> toMap() {
    return {
      'partnerDeliveryRatePerKm': partnerDeliveryRatePerKm,
    };
  }

  factory SystemSettingsModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) return SystemSettingsModel();
    Map<String, dynamic> map = doc.data() as Map<String, dynamic>;
    return SystemSettingsModel(
      partnerDeliveryRatePerKm: (map['partnerDeliveryRatePerKm'] ?? 10.0).toDouble(),
    );
  }
}
