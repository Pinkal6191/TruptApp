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
import 'user_approval_screen.dart';
import 'product_management_screen.dart';
import 'admin_reports_screen.dart';

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
                    leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.how_to_reg, color: Colors.white)),
                    title: const Text('User Management'),
                    subtitle: const Text('Approve new partners/distributors'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserApprovalScreen())),
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
}
