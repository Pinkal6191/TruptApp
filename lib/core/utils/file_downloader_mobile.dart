import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

Future<void> downloadFile(List<int> bytes, String fileName, {String? mimeType}) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    final file = File(path);
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(path, mimeType: mimeType)]);
  } catch (e) {
    debugPrint('Error downloading file: $e');
  }
}
