import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/backup_service.dart';

class AdminBackupScreen extends StatefulWidget {
  const AdminBackupScreen({Key? key}) : super(key: key);

  @override
  State<AdminBackupScreen> createState() => _AdminBackupScreenState();
}

class _AdminBackupScreenState extends State<AdminBackupScreen> {
  final BackupService _backupService = BackupService();
  bool _isBackingUp = false;
  String? _lastBackupDate;

  @override
  void initState() {
    super.initState();
    _loadLastBackupDate();
  }

  Future<void> _loadLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastBackupDate = prefs.getString('last_backup_date');
    });
  }

  Future<void> _saveLastBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now());
    await prefs.setString('last_backup_date', now);
    setState(() {
      _lastBackupDate = now;
    });
  }

  Future<void> _performBackup() async {
    setState(() {
      _isBackingUp = true;
    });

    try {
      await _backupService.exportDatabase();
      await _saveLastBackupDate();
      
      final nowStr = DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now());
      final subject = Uri.encodeComponent('Database Backup - $nowStr');
      final body = Uri.encodeComponent('Please find the attached JSON backup file generated on $nowStr.\n\nNOTE: The file has been downloaded to your device. Please attach it to this email before sending!');
      final url = Uri.parse('mailto:truptenterprise26@gmail.com?subject=$subject&body=$body');
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup generated! Please attach it to the email.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate backup: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Backup & Export', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manual Database Backup',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Click the button below to fetch all your live data (Orders, Customers, Expenses, Quotations, and Inventory) and download it directly to your device as a JSON file.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.blue, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Last Backup Performed:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text(
                          _lastBackupDate ?? 'Never',
                          style: TextStyle(color: _lastBackupDate == null ? Colors.red : Colors.blue.shade700, fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isBackingUp ? null : _performBackup,
                icon: _isBackingUp ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.download, color: Colors.white),
                label: Text(
                  _isBackingUp ? 'Generating Backup...' : 'Generate & Download Backup',
                  style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Note: It may take a few seconds to compile all data.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
          ],
        ),
      ),
    );
  }
}
