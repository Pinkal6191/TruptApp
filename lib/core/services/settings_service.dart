import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/system_settings_model.dart';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<SystemSettingsModel> getSettings() async {
    final doc = await _firestore.collection('system_settings').doc('general').get();
    return SystemSettingsModel.fromFirestore(doc);
  }

  Future<void> updateDeliveryRate(double newRate) async {
    await _firestore.collection('system_settings').doc('general').set({
      'partnerDeliveryRatePerKm': newRate,
    }, SetOptions(merge: true));
  }
}
