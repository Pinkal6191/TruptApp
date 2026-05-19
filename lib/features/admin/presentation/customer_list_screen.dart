import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:csv/csv.dart';
import '../../../core/utils/file_downloader.dart';
import '../../../core/models/customer_model.dart';
import '../../customers/bloc/customer_bloc.dart';
import '../../customers/bloc/customer_event.dart';
import '../../customers/bloc/customer_state.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CustomerBloc>().add(LoadCustomers());
  }

  Future<void> _exportToCsv(List<CustomerModel> customers) async {
    List<List<dynamic>> rows = [];
    // Headers
    rows.add([
      'Shop/Customer Name',
      'Mobile Number',
      'Address',
      'GST Number',
      'Total Orders',
      'Total Spent (₹)',
      'Created At'
    ]);

    for (var customer in customers) {
      rows.add([
        customer.shopName,
        customer.mobileNumber,
        customer.address,
        customer.gstNumber,
        customer.totalOrders,
        customer.totalAmountSpent,
        customer.createdAt.toString(),
      ]);
    }

    String csvData = Csv().encode(rows);
    final bytes = utf8.encode(csvData);
    final fileName = 'customer_report_${DateTime.now().millisecondsSinceEpoch}.csv';
    
    await downloadFile(bytes, fileName, mimeType: 'text/csv');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report downloaded successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Customer Directory'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        actions: [
          BlocBuilder<CustomerBloc, CustomerState>(
            builder: (context, state) {
              if (state is CustomersLoaded && state.customers.isNotEmpty) {
                return IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Export CSV',
                  onPressed: () => _exportToCsv(state.customers),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: BlocBuilder<CustomerBloc, CustomerState>(
        builder: (context, state) {
          if (state is CustomerLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is CustomersLoaded) {
            if (state.customers.isEmpty) {
              return const Center(child: Text('No customers found.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.customers.length,
              itemBuilder: (context, index) {
                final customer = state.customers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1),
                      child: Text(
                        customer.shopName.isNotEmpty ? customer.shopName[0].toUpperCase() : 'C',
                        style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(customer.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${customer.mobileNumber}\nOrders: ${customer.totalOrders} | Spent: ₹${customer.totalAmountSpent.toStringAsFixed(2)}'),
                    isThreeLine: true,
                  ),
                );
              },
            );
          } else if (state is CustomerError) {
            return Center(child: Text('Error: ${state.message}', style: const TextStyle(color: Colors.red)));
          }
          return const SizedBox();
        },
      ),
    );
  }
}
