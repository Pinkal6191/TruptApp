import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:csv/csv.dart';
import '../../../core/utils/file_downloader.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/utils/route_tracker.dart';
import '../../customers/bloc/customer_bloc.dart';
import '../../customers/bloc/customer_event.dart';
import '../../customers/bloc/customer_event.dart';
import '../../customers/bloc/customer_state.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class PrivateLabelCustomersScreen extends StatefulWidget {
  const PrivateLabelCustomersScreen({super.key});

  @override
  State<PrivateLabelCustomersScreen> createState() => _PrivateLabelCustomersScreenState();
}

class _PrivateLabelCustomersScreenState extends State<PrivateLabelCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'All'; // 'All', 'Repeated'
  int _currentPage = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('private_label_customer_list');
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
            Text(isEdit ? 'Edit Customer' : 'Add Custom Label Customer',
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
                  isPrivateLabel:   true,
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
    return BlocBuilder<CustomerBloc, CustomerState>(
      builder: (context, state) {
        final authState = context.read<AuthBloc>().state;
        final isAdmin = authState is Authenticated && authState.user.role == 'admin';
        
        if (state is CustomerLoading) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Private Label Customers'),
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E3A8A),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        } else if (state is CustomersLoaded) {
          final query = _searchQuery.toLowerCase().trim();
          var filteredCustomers = state.customers.where((c) {
            if (!c.isPrivateLabel) return false;
            if (query.isEmpty) return true;
            return c.shopName.toLowerCase().contains(query) ||
                c.mobileNumber.toLowerCase().contains(query) ||
                c.address.toLowerCase().contains(query);
          }).toList();

          // Apply All / Repeated Orders filter
          if (_filterType == 'Repeated') {
            filteredCustomers = filteredCustomers.where((c) => c.totalOrders > 1).toList();
          }

          final totalItems = filteredCustomers.length;
          final totalPages = (totalItems / _pageSize).ceil();
          final hasBottomBar = totalPages > 1;

          // Adjust current page if it goes out of bounds due to filtering
          if (_currentPage > totalPages && totalPages > 0) {
            _currentPage = totalPages;
          }

          final paginatedCustomers = filteredCustomers.skip((_currentPage - 1) * _pageSize).take(_pageSize).toList();

          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Private Label Customers'),
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E3A8A),
              actions: [
                if (state.customers.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Export CSV',
                    onPressed: () => _exportToCsv(filteredCustomers),
                  ),
              ],
            ),
            floatingActionButtonLocation: _AboveBottomBarFabLocation(hasBottomBar: hasBottomBar),
            floatingActionButton: isAdmin ? FloatingActionButton.extended(
              onPressed: () => _showCustomerDialog(),
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Customer'),
              elevation: 4,
            ) : null,
            body: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    }),
                    decoration: InputDecoration(
                      hintText: 'Search by name, mobile, or address...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A8A)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _currentPage = 1;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
                        borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                      ),
                    ),
                  ),
                ),

                // Filter chips for All / Repeated Orders
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Customers'),
                        selected: _filterType == 'All',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _filterType = 'All';
                              _currentPage = 1;
                            });
                          }
                        },
                        selectedColor: const Color(0xFFEFF6FF),
                        checkmarkColor: const Color(0xFF1E3A8A),
                        labelStyle: TextStyle(
                          color: _filterType == 'All' ? const Color(0xFF1E3A8A) : Colors.grey.shade600,
                          fontWeight: _filterType == 'All' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(
                          color: _filterType == 'All' ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Repeated Orders'),
                        selected: _filterType == 'Repeated',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _filterType = 'Repeated';
                              _currentPage = 1;
                            });
                          }
                        },
                        selectedColor: const Color(0xFFECFDF5),
                        checkmarkColor: const Color(0xFF10B981),
                        labelStyle: TextStyle(
                          color: _filterType == 'Repeated' ? const Color(0xFF047857) : Colors.grey.shade600,
                          fontWeight: _filterType == 'Repeated' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(
                          color: _filterType == 'Repeated' ? const Color(0xFF34D399).withValues(alpha: 0.5) : Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ),

                // Count badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Showing ${totalItems > 0 ? (_currentPage - 1) * _pageSize + 1 : 0} - ${(_currentPage * _pageSize) < totalItems ? (_currentPage * _pageSize) : totalItems} of $totalItems customer${totalItems == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

                // List
                Expanded(
                  child: paginatedCustomers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_search, size: 60, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isEmpty ? 'No customers found.' : 'No matching customers found.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: paginatedCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = paginatedCustomers[index];
                            return _CustomerCard(
                              customer: customer,
                              isAdmin: isAdmin,
                              onEdit: () => _showCustomerDialog(existing: customer),
                              onDelete: () => _confirmDelete(customer),
                            );
                          },
                        ),
                ),

                // Pagination Controls
                if (totalPages > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                          icon: const Icon(Icons.arrow_back_ios, size: 14),
                          label: const Text('Prev', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                          ),
                        ),
                        Text(
                          'Page $_currentPage of $totalPages',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF475569)),
                        ),
                        TextButton.icon(
                          onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                          label: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                          icon: const Icon(Icons.arrow_forward_ios, size: 14),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        } else if (state is CustomerError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              title: const Text('Private Label Customers'),
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E3A8A),
            ),
            body: Center(
              child: Text(
                'Error: ${state.message}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Private Label Customers'),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E3A8A),
          ),
          body: const SizedBox(),
        );
      },
    );
  }
}

// ── Customer Card widget ────────────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.isAdmin,
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

            // Action buttons (Admin only)
            if (isAdmin)
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

class _AboveBottomBarFabLocation extends FloatingActionButtonLocation {
  final bool hasBottomBar;
  const _AboveBottomBarFabLocation({required this.hasBottomBar});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final double fabWidth = geometry.floatingActionButtonSize.width;
    final double fabHeight = geometry.floatingActionButtonSize.height;
    final double screenWidth = geometry.scaffoldSize.width;
    final double screenHeight = geometry.scaffoldSize.height;
    
    final double x = screenWidth - fabWidth - 16;
    final double y = screenHeight - fabHeight - 16 - (hasBottomBar ? 60 : 0);
    
    return Offset(x, y);
  }
}
