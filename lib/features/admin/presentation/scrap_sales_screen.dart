import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/models/scrap_sale_model.dart';

class ScrapSalesScreen extends StatelessWidget {
  const ScrapSalesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrap (Bhangar) Sales', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddScrapDialog(context),
        backgroundColor: const Color(0xFF1A237E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Sale', style: TextStyle(color: Colors.white)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('scrap_sales').orderBy('date', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No scrap sales logged yet.'));
          }

          final sales = snapshot.data!.docs.map((d) => ScrapSaleModel.fromFirestore(d)).toList();
          
          double totalRevenue = 0;
          double totalKgs = 0;
          for (var s in sales) {
            totalRevenue += s.amount;
            totalKgs += s.weightKg;
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF1A237E).withValues(alpha: 0.05),
                child: Column(
                  children: [
                    const Text('Total Scrap Sold', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryStat('Total Revenue', '₹${totalRevenue.toStringAsFixed(0)}', Colors.green),
                        _SummaryStat('Total Weight', '${totalKgs.toStringAsFixed(1)} kg', Colors.blueGrey),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sales.length,
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    return _ScrapSaleCard(sale: sale);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddScrapDialog(BuildContext context) {
    final buyerController = TextEditingController();
    final weightController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Scrap Sale'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: buyerController,
                  decoration: const InputDecoration(labelText: 'Buyer / Bhangarwala Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: weightController,
                  decoration: const InputDecoration(labelText: 'Total Weight (kg)', suffixText: 'kg'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Total Amount Received (₹)', prefixText: '₹'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes / Material Description'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E)),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final amount = double.tryParse(amountController.text) ?? 0;
                final weight = double.tryParse(weightController.text) ?? 0;

                await FirebaseFirestore.instance.collection('scrap_sales').add({
                  'buyerName': buyerController.text.trim(),
                  'weightKg': weight,
                  'amount': amount,
                  'description': notesController.text.trim(),
                  'date': Timestamp.now(),
                });

                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save Sale', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }
}

class _ScrapSaleCard extends StatelessWidget {
  final ScrapSaleModel sale;
  const _ScrapSaleCard({Key? key, required this.sale}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.shade100,
          child: const Icon(Icons.recycling, color: Colors.blueGrey),
        ),
        title: Text(sale.buyerName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(DateFormat('MMM dd, yyyy').format(sale.date)),
            if (sale.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(sale.description, style: const TextStyle(fontStyle: FontStyle.italic)),
            ]
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₹${sale.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
            const SizedBox(height: 4),
            Text('${sale.weightKg} kg', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        onLongPress: () => _deleteSale(context),
      ),
    );
  }

  void _deleteSale(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Sale?'),
        content: const Text('Are you sure you want to delete this scrap sale log?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('scrap_sales').doc(sale.id).delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
