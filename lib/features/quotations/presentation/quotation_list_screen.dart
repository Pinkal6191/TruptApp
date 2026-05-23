import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/quotation_model.dart';
import '../services/quotation_pdf_service.dart';
import 'create_quotation_screen.dart';

class QuotationListScreen extends StatefulWidget {
  const QuotationListScreen({super.key});

  @override
  State<QuotationListScreen> createState() => _QuotationListScreenState();
}

class _QuotationListScreenState extends State<QuotationListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _shareQuotationText(QuotationModel q) async {
    final buffer = StringBuffer();
    buffer.writeln('Hello Sir,');
    buffer.writeln();
    buffer.writeln('As discussed, please find our quotation for ${q.quotationType.toLowerCase()} water bottles:');
    buffer.writeln();

    for (var item in q.items) {
      buffer.writeln('🔹 ${item.productName}: ₹${item.pricePerUnit.toStringAsFixed(0)} per ${item.unitType.toLowerCase().replaceAll("crates", "crate")}');
    }

    if (q.oneTimeCharge > 0) {
      buffer.writeln();
      buffer.writeln('🔹 One-Time Setup & Custom Label Development Charge: ₹${q.oneTimeCharge.toStringAsFixed(0)}');
      buffer.writeln();
      buffer.writeln('The setup cost includes custom label design, printing setup, and branding process.');
    }

    buffer.writeln();
    buffer.writeln('Looking forward to working with you.');
    buffer.writeln('Thank you.');
    buffer.writeln();
    buffer.writeln('Regards,');
    buffer.writeln('Trupt – Har Boond Mein Trupti');

    final formattedText = buffer.toString();

    // 1. Copy to clipboard
    await Clipboard.setData(ClipboardData(text: formattedText));

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message copied to clipboard! Opening WhatsApp...'),
          backgroundColor: Colors.green,
        ),
      );
    }

    // 2. Launch WhatsApp sharing
    final whatsappUrl = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(formattedText)}');
    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(whatsappUrl);
      }
    } catch (_) {}
  }

  void _deleteQuotation(QuotationModel quotation) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Quotation'),
        content: Text('Are you sure you want to delete quotation ${quotation.quotationNumber}? This action is permanent.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx); // close dialog
              
              // Show loading snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleting quotation...')),
              );

              try {
                await FirebaseFirestore.instance
                    .collection('quotations')
                    .doc(quotation.id)
                    .delete();

                if (mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Quotation ${quotation.quotationNumber} deleted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting quotation: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Quotation Directory'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search & Filter Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by client name or quote number...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A8A)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),

          // Quotations Stream List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('quotations')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _emptyState();
                }

                // Parse and filter
                final quotations = docs.map((doc) => QuotationModel.fromFirestore(doc)).where((q) {
                  return q.shopName.toLowerCase().contains(_searchQuery) ||
                      q.quotationNumber.toLowerCase().contains(_searchQuery);
                }).toList();

                if (quotations.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No matching quotations found.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: quotations.length,
                  itemBuilder: (context, index) {
                    final q = quotations[index];
                    final now = DateTime.now();
                    final bool isExpired = q.validUntil.isBefore(now);
                    final daysLeft = q.validUntil.difference(now).inDays;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shadowColor: Colors.black12,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    q.shopName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isExpired ? Colors.red.shade50 : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isExpired ? Colors.red.shade200 : Colors.green.shade200),
                                  ),
                                  child: Text(
                                    isExpired ? 'Expired' : '$daysLeft days left',
                                    style: TextStyle(
                                      color: isExpired ? Colors.red.shade800 : Colors.green.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              q.quotationNumber,
                              style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 12),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Quote Type', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text(q.quotationType, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text('Estimated Cost', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text('₹${q.finalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 14)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Created Date', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    Text(DateFormat('dd MMM yyyy').format(q.createdAt), style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Download & Share PDF button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      foregroundColor: const Color(0xFF1E3A8A),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                                    label: const Text('Download / Print PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    onPressed: () {
                                      QuotationPdfService.generateAndShareQuotation(q);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // WhatsApp Share Text
                                IconButton(
                                  icon: const Icon(Icons.share, color: Colors.green),
                                  tooltip: 'Copy & Share WhatsApp Text',
                                  onPressed: () => _shareQuotationText(q),
                                ),
                                const SizedBox(width: 4),
                                // Edit
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                                  tooltip: 'Edit Quotation details',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreateQuotationScreen(existingQuotation: q),
                                      ),
                                    );
                                  },
                                ),
                                // Delete
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  tooltip: 'Delete Quotation',
                                  onPressed: () => _deleteQuotation(q),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Estimate', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateQuotationScreen(),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.request_quote_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No Quotations Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the button below to draft and generate your first customer proforma estimate.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
