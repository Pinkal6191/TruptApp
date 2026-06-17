import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> exportDatabase() async {
    final Map<String, dynamic> backupData = {};
    final collections = [
      'orders',
      'customers',
      'inventory',
      'expenses',
      'contracts',
      'quotations',
      'production',
      'raw_materials',
      'settings',
      'users'
    ];

    for (var col in collections) {
      final snapshot = await _firestore.collection(col).get();
      backupData[col] = snapshot.docs.map((d) {
        final data = d.data();
        data['document_id'] = d.id; // Preserve ID
        return _encodeValue(data);
      }).toList();
    }

    final jsonString = jsonEncode(backupData);
    final bytes = utf8.encode(jsonString);
    
    final fileName = 'trupt_backup_${DateTime.now().toIso8601String().split('T')[0]}.json';
    
    await Share.shareXFiles([
      XFile.fromData(bytes, name: fileName, mimeType: 'application/json')
    ], subject: 'Database Backup');
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {'_seconds': value.seconds, '_nanoseconds': value.nanoseconds, 'isoString': value.toDate().toIso8601String()};
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is Map) {
      return value.map((k, v) => MapEntry(k, _encodeValue(v)));
    } else if (value is List) {
      return value.map((v) => _encodeValue(v)).toList();
    }
    return value;
  }
}
