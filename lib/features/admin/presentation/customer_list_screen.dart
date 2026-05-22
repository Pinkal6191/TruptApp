import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:csv/csv.dart';
import '../../../core/utils/file_downloader.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/utils/route_tracker.dart';
import '../../customers/bloc/customer_bloc.dart';
import '../../customers/bloc/customer_event.dart';
import '../../customers/bloc/customer_state.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('customer_list');
    context.read<CustomerBloc>().add(LoadCustomers());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Export ────────────────────────────────────────────────────────────────
  Future<void> _exportToCsv(List<CustomerModel> customers) async {
    List<List<dynamic>> rows = [];
    rows.add([
      'Shop/Customer Name',
      'Mobile Number',
      'Address',
      'GST Number',
      'Total Orders',
      'Total Spent (₹)',
      'Created At'
    ]);
    for (var c in customers) {
      rows.add([
        c.shopName,
        c.mobileNumber,
        c.address,
        c.gstNumber,
        c.totalOrders,
        c.totalAmountSpent,
        c.createdAt.toString(),
      ]);
    }
    final bytes = utf8.encode(Csv().encode(rows));
    final fileName = 'customer_report_${DateTime.now().millisecondsSinceEpoch}.csv';
    await downloadFile(bytes, fileName, mimeType: 'text/csv');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report downloaded successfully!')),
      );
    }
  }

  // ── Add / Edit dialog ─────────────────────────────────────────────────────
  void _showCustomerDialog({CustomerModel? existing}) {
    final nameCtrl    = TextEditingController(text: existing?.shopName    ?? '');
    final mobileCtrl  = TextEditingController(text: existing?.mobileNumber ?? '');
    final addressCtrl = TextEditingController(text: existing?.address      ?? '');
    final gstCtrl     = TextEditingController(text: existing?.gstNumber    ?? '');
    final formKey     = GlobalKey<FormState>();
    final isEdit      = existing != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isEdit ? Icons.edit : Icons.person_add,
                color: const Color(0xFF1E3A8A)),
            const SizedBox(width: 8),
            Text(isEdit ? 'Edit Customer' : 'Add Customer',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A))),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl,    'Shop / Customer Name *', Icons.store,        required: true),
                const SizedBox(height: 12),
                _dialogField(mobileCtrl,  'Mobile Number',           Icons.phone,        keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                _dialogField(addressCtrl, 'Address',                 Icons.location_on),
                const SizedBox(height: 12),
                _dialogField(gstCtrl,     'GST Number',              Icons.receipt_long),
                if (isEdit) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF1E3A8A)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Orders & total spent are managed by the order system and cannot be edited here.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              if (isEdit) {
                final updated = CustomerModel(
                  id:               existing.id,
                  shopName:         nameCtrl.text.trim(),
                  mobileNumber:     mobileCtrl.text.trim(),
                  address:          addressCtrl.text.trim(),
                  gstNumber:        gstCtrl.text.trim(),
                  partnerId:        existing.partnerId,
                  totalOrders:      existing.totalOrders,
                  totalAmountSpent: existing.totalAmountSpent,
                  createdAt:        existing.createdAt,
                );
                context.read<CustomerBloc>().add(UpdateCustomer(updated));
              } else {
                final newId = DateTime.now().millisecondsSinceEpoch.toString();
                final newCustomer = CustomerModel(
                  id:               newId,
                  shopName:         nameCtrl.text.trim(),
                  mobileNumber:     mobileCtrl.text.trim(),
                  address:          addressCtrl.text.trim(),
                  gstNumber:        gstCtrl.text.trim(),
                  partnerId:        'admin',
                  totalOrders:      0,
                  totalAmountSpent: 0.0,
                  createdAt:        DateTime.now(),
                );
                context.read<CustomerBloc>().add(AddCustomer(newCustomer));
              }

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isEdit ? 'Customer updated!' : 'Customer added!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text(isEdit ? 'Save Changes' : 'Add Customer'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF1E3A8A)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        isDense: true,
      ),
      validator: required
          ? (val) => (val == null || val.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  // ── Delete confirm ─────────────────────────────────────────────────────────
  void _confirmDelete(CustomerModel customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Delete Customer', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: customer.shopName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                  text: '?\n\nThis removes them from the directory but does NOT delete their orders.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              context.read<CustomerBloc>().add(DeleteCustomer(customer.id));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${customer.shopName} deleted.'),
                  backgroundColor: Colors.red.shade700,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
                final query = _searchQuery.toLowerCase().trim();
                final filtered = state.customers.where((c) {
                  if (query.isEmpty) return true;
                  return c.shopName.toLowerCase().contains(query) ||
                      c.mobileNumber.toLowerCase().contains(query) ||
                      c.address.toLowerCase().contains(query);
                }).toList();
                return IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Export CSV',
                  onPressed: () => _exportToCsv(filtered),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
        elevation: 4,
      ),
      body: BlocBuilder<CustomerBloc, CustomerState>(
        builder: (context, state) {
          if (state is CustomerLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is CustomersLoaded) {
            final query = _searchQuery.toLowerCase().trim();
            final filteredCustomers = state.customers.where((c) {
              if (query.isEmpty) return true;
              return c.shopName.toLowerCase().contains(query) ||
                  c.mobileNumber.toLowerCase().contains(query) ||
                  c.address.toLowerCase().contains(query);
            }).toList();

            return Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search by name, mobile, or address...',
                      prefixIcon:
                          const Icon(Icons.search, color: Color(0xFF1E3A8A)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF1E3A8A), width: 1.5),
                      ),
                    ),
                  ),
                ),

                // Count badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filteredCustomers.length} customer${filteredCustomers.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

                // List
                Expanded(
                  child: filteredCustomers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_search,
                                  size: 60, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'No customers yet.\nTap "+ Add Customer" to get started.'
                                    : 'No matching customers found.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = filteredCustomers[index];
                            return _CustomerCard(
                              customer: customer,
                              onEdit: () =>
                                  _showCustomerDialog(existing: customer),
                              onDelete: () => _confirmDelete(customer),
                            );
                          },
                        ),
                ),
              ],
            );
          } else if (state is CustomerError) {
            return Center(
                child: Text('Error: ${state.message}',
                    style: const TextStyle(color: Colors.red)));
          }
          return const SizedBox();
        },
      ),
    );
  }
}

// ── Customer Card widget ────────────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        customer.shopName.isNotEmpty ? customer.shopName[0].toUpperCase() : 'C';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
              child: Text(
                initial,
                style: const TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.shopName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 4),
                  if (customer.mobileNumber.isNotEmpty)
                    _infoRow(Icons.phone, customer.mobileNumber),
                  if (customer.address.isNotEmpty)
                    _infoRow(Icons.location_on, customer.address),
                  if (customer.gstNumber.isNotEmpty &&
                      customer.gstNumber != 'URP')
                    _infoRow(Icons.receipt_long, customer.gstNumber),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    children: [
                      _statChip(Icons.shopping_bag_outlined,
                          '${customer.totalOrders} orders',
                          Colors.blue.shade700),
                      _statChip(Icons.currency_rupee,
                          customer.totalAmountSpent.toStringAsFixed(0),
                          Colors.green.shade700),
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Color(0xFF1E3A8A), size: 20),
                  tooltip: 'Edit Customer',
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: Colors.red.shade400, size: 20),
                  tooltip: 'Delete Customer',
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
