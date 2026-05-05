import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../orders/bloc/order_bloc.dart';
import '../../orders/bloc/order_event.dart';
import '../../orders/bloc/order_state.dart';
import '../../../core/models/order_model.dart';
import 'package:intl/intl.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _filterRole = 'all'; // all, partner, distributor

  @override
  void initState() {
    super.initState();
    context.read<OrderBloc>().add(LoadAllOrders());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Business Reports'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Text('Filter by Role:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                _filterChip('All', 'all'),
                const SizedBox(width: 8),
                _filterChip('Partners', 'partner'),
                const SizedBox(width: 8),
                _filterChip('Distributors', 'distributor'),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<OrderBloc, OrderState>(
              builder: (context, state) {
                if (state is OrderLoading) return const Center(child: CircularProgressIndicator());
                if (state is OrdersLoaded) {
                  final loadedState = state as OrdersLoaded;
                  final filteredOrders = loadedState.orders.where((o) {
                    if (_filterRole == 'all') return true;
                    return o.creatorRole == _filterRole;
                  }).toList();

                  if (filteredOrders.isEmpty) return const Center(child: Text('No orders found for this filter.'));

                  double totalSales = filteredOrders.fold(0, (sum, o) => sum + o.finalAmount);

                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Filtered Sales', style: TextStyle(color: Colors.white70, fontSize: 16)),
                            Text('₹${totalSales.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                            Text('${filteredOrders.length} Orders total', style: const TextStyle(color: Colors.white60)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final o = filteredOrders[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(o.shopName.isEmpty ? o.partnerName : o.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Created by: ${o.partnerName} (${o.creatorRole})\n${DateFormat('dd MMM yyyy').format(o.createdAt)}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₹${o.finalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(o.paymentStatus, style: TextStyle(color: o.paymentStatus == 'Paid' ? Colors.green : Colors.orange, fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    bool isSelected = _filterRole == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterRole = value);
      },
      selectedColor: const Color(0xFF1E3A8A),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }
}
