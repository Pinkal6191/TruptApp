import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/models/order_model.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  bool _isLoading = true;
  List<OrderModel> _supplyOrders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSupplyOrders();
  }

  Future<void> _loadSupplyOrders() async {
    try {
      setState(() { _isLoading = true; _error = null; });
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('isSupplyOrder', isEqualTo: true)
          .get();

      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _supplyOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByProduct() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var order in _supplyOrders) {
      for (var item in order.items) {
        grouped.putIfAbsent(item.productName, () => []);
        grouped[item.productName]!.add({
          'date': order.createdAt,
          'distributor': order.partnerName,
          'qty': item.quantity,
          'invoice': order.invoiceNumber,
        });
      }
    }

    for (var key in grouped.keys) {
      grouped[key]!.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Stock Transfer History'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Stock Transfer History'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text('Error: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadSupplyOrders, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final grouped = _groupByProduct();

    if (grouped.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Stock Transfer History'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text('No stock transfers found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final productNames = grouped.keys.toList()..sort();

    return DefaultTabController(
      length: productNames.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Stock Transfer History'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _loadSupplyOrders,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: const Color(0xFF1E3A8A),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF1E3A8A),
            tabs: productNames.map((name) => Tab(text: name)).toList(),
          ),
        ),
        body: TabBarView(
          children: productNames.map((productName) {
            final entries = grouped[productName]!;
            final totalCrates = entries.fold<int>(0, (sum, e) => sum + (e['qty'] as int));

            final Map<String, int> byDistributor = {};
            for (var e in entries) {
              final dist = e['distributor'] as String;
              byDistributor[dist] = (byDistributor[dist] ?? 0) + (e['qty'] as int);
            }

            return Column(
              children: [
                // Total Banner
                Container(
                  width: double.infinity,
                  color: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Sent', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('$totalCrates Crates', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Transfers', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('${entries.length} Bills', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Distributor Summary Strip
                if (byDistributor.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFE8EDF5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: byDistributor.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 14, color: Color(0xFF1E3A8A)),
                              const SizedBox(width: 4),
                              Text(
                                '${entry.key}: ${entry.value} crates',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ),

                // Transfer List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final date = entry['date'] as DateTime;
                      final qty = entry['qty'] as int;
                      final distributor = entry['distributor'] as String;
                      final invoice = entry['invoice'] as String;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 1.5,
                        shadowColor: Colors.black12,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                                child: Text(
                                  '${entries.length - index}',
                                  style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(distributor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        const SizedBox(width: 12),
                                        const Icon(Icons.receipt, size: 12, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(invoice.isEmpty ? 'No Invoice' : invoice, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '+$qty',
                                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
