import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../products/bloc/product_bloc.dart';
import '../../products/bloc/product_event.dart';
import '../../products/bloc/product_state.dart';
import '../../orders/bloc/order_bloc.dart';
import '../../orders/bloc/order_event.dart';
import '../../orders/presentation/order_history_screen.dart';
import '../../orders/presentation/create_order_screen.dart';
import '../../expenses/bloc/expense_bloc.dart';
import '../../expenses/bloc/expense_event.dart';
import '../../expenses/bloc/expense_state.dart';
import '../../expenses/presentation/expense_management_screen.dart';
import 'product_management_screen.dart';
import 'admin_reports_screen.dart';
import 'user_management_screen.dart';
import 'customer_list_screen.dart';
import '../../../core/services/database_maintenance_service.dart';
import '../../../core/widgets/sales_trend_graph.dart';
import '../../../core/widgets/regular_customers_graph.dart';
import '../../../core/widgets/crate_sales_breakdown.dart';
import '../../orders/bloc/order_bloc.dart';
import '../../orders/bloc/order_state.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    context.read<ProductBloc>().add(LoadProducts());
    context.read<ExpenseBloc>().add(LoadExpenses());
    context.read<OrderBloc>().add(WatchOrders());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<ProductBloc>().add(ResetProductState());
              context.read<OrderBloc>().add(ResetOrderState());
              context.read<ExpenseBloc>().add(ResetExpenseState());
              context.read<AuthBloc>().add(LogoutEvent());
            },
          )
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (authState is! Authenticated) return const SizedBox();
          final user = authState.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user.name}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const Text('Administrator Control Center', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .where('isApproved', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                      final count = snapshot.data!.docs.length;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFF59E0B),
                            child: Icon(Icons.warning_amber_rounded, color: Colors.white),
                          ),
                          title: Text(
                            '$count Registrations Pending',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                          ),
                          subtitle: const Text('New users are waiting for your approval.'),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                              );
                            },
                            child: const Text('Review'),
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),

                const Text(
                  'Network Coverage & Summary',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('customers').snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                          return _buildSummaryIndicatorCard('Customers', '$count Covered', Icons.groups, Colors.purple);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('role', isEqualTo: 'distributor')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                          return _buildSummaryIndicatorCard('Distributors', '$count Active', Icons.store, Colors.teal);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('role', isEqualTo: 'partner')
                            .snapshots(),
                        builder: (context, snapshot) {
                          final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                          return _buildSummaryIndicatorCard('Partners', '$count Active', Icons.handshake, Colors.indigo);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Supply Stock',
                        'Send stock to distributors',
                        Icons.add_shopping_cart,
                        Colors.green,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen())),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Create Retail Order',
                        'Direct sale with partner referral',
                        Icons.person_add_alt_1,
                        Colors.purple,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen(isRetailOrder: true))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'All Orders',
                        'View and manage orders',
                        Icons.receipt_long,
                        Colors.blue,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Products',
                        'Manage catalog & prices',
                        Icons.inventory,
                        Colors.orange,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductManagementScreen())),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Reports',
                        'Sales & commissions',
                        Icons.analytics,
                        Colors.indigo,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportsScreen())),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'Sales Analytics',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                BlocBuilder<OrderBloc, OrderState>(
                  builder: (context, orderState) {
                    if (orderState is OrdersLoaded) {
                      return Column(
                        children: [
                          SalesTrendGraph(orders: orderState.orders),
                          const SizedBox(height: 16),
                          CrateSalesBreakdown(orders: orderState.orders),
                          const SizedBox(height: 16),
                          RegularCustomersGraph(orders: orderState.orders),
                        ],
                      );
                    }
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'System Health',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                BlocBuilder<ExpenseBloc, ExpenseState>(
                  builder: (context, state) {
                    double totalExpense = 0.0;
                    if (state is ExpensesLoaded) {
                      totalExpense = state.expenses.fold(0, (sum, item) => sum + item.amount);
                    }
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.money_off, color: Colors.white)),
                        title: const Text('Total Expenses Logged'),
                        trailing: Text('₹${totalExpense.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseManagementScreen())),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.recent_actors, color: Colors.white)),
                    title: const Text('Customer Directory'),
                    subtitle: const Text('View repeat customers and export list'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen())),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.people, color: Colors.white)),
                    title: const Text('User Management'),
                    subtitle: const Text('Manage roles, approvals, and accounts'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.calculate, color: Colors.white)),
                    title: const Text('Maintenance: Update Old Bills to 5% GST'),
                    subtitle: const Text('Recalculates subtotal and GST for existing orders'),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () => _showMigrationDialog(context),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.delete_forever, color: Colors.white)),
                    title: const Text('Factory Reset (Wipe Data)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Deletes all orders, customers, and partner accounts for live deployment', style: TextStyle(color: Colors.red)),
                    trailing: const Icon(Icons.warning, color: Colors.red),
                    onTap: () => _showWipeDataDialog(context),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showMigrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update All Bills to 5% GST?'),
        content: const Text('This will recalculate the Subtotal and GST amount for all existing orders using the new 5% rate. The Total Price will remain unchanged.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _migrateGST();
            },
            child: const Text('Start Migration'),
          ),
        ],
      ),
    );
  }

  Future<void> _migrateGST() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting GST Migration...')));
    try {
      final snapshot = await FirebaseFirestore.instance.collection('orders').get();
      int count = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        double finalAmount = (data['finalAmount'] ?? 0).toDouble();
        if (finalAmount > 0) {
          double newSubtotal = finalAmount / 1.05;
          double newGst = finalAmount - newSubtotal;
          await doc.reference.update({
            'subtotal': newSubtotal,
            'gstAmount': newGst,
          });
          count++;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Migration complete! Updated $count orders.'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Migration failed: $e'), backgroundColor: Colors.red));
    }
  }

  void _showWipeDataDialog(BuildContext context) {
    String confirmationText = '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('⚠️ DANGER: WIPE ALL DATA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('This action will permanently delete all Orders, Customers, and Non-Admin Users. Products and the Admin account will remain.'),
                  const SizedBox(height: 16),
                  const Text('Type "WIPE ALL DATA" below to confirm:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (val) {
                      setDialogState(() {
                        confirmationText = val;
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'WIPE ALL DATA',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: confirmationText == 'WIPE ALL DATA' ? () {
                    Navigator.pop(context);
                    _executeWipe();
                  } : null,
                  child: const Text('PERMANENTLY DELETE'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _executeWipe() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wiping data... Please wait.')));
    try {
      final service = DatabaseMaintenanceService();
      await service.wipeAllDataExceptAdminAndProducts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data wipe successful. App is ready for live use.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error wiping data: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildSummaryIndicatorCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
