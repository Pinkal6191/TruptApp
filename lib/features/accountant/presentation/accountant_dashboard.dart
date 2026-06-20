import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../orders/bloc/order_bloc.dart';
import '../../orders/bloc/order_state.dart';
import '../../orders/presentation/order_history_screen.dart';
import '../../products/bloc/product_bloc.dart';
import '../../products/bloc/product_event.dart';
import '../../orders/bloc/order_event.dart';
import '../../../core/utils/route_tracker.dart';
import '../../admin/presentation/admin_reports_screen.dart';

class AccountantDashboard extends StatefulWidget {
  const AccountantDashboard({super.key});

  @override
  State<AccountantDashboard> createState() => _AccountantDashboardState();
}

class _AccountantDashboardState extends State<AccountantDashboard> {
  @override
  void initState() {
    super.initState();
    context.read<OrderBloc>().add(WatchOrders());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) return const SizedBox();
        final user = authState.user;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Accountant Dashboard'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E3A8A),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.sync),
                tooltip: 'Refresh Orders',
                onPressed: () {
                  context.read<OrderBloc>().add(WatchOrders());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refreshing orders...')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () {
                  context.read<ProductBloc>().add(ResetProductState());
                  context.read<OrderBloc>().add(ResetOrderState());
                  context.read<AuthBloc>().add(LogoutEvent());
                },
              )
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<OrderBloc>().add(WatchOrders());
              await Future.delayed(const Duration(milliseconds: 800));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${user.name}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const Text('CA / Accountant Control Center', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),

                  // Summary Section
                  BlocBuilder<OrderBloc, OrderState>(
                    builder: (context, orderState) {
                      double totalSales = 0.0;
                      double totalCollected = 0.0;
                      double totalPending = 0.0;

                      if (orderState is OrdersLoaded) {
                        final filteredOrders = orderState.orders.where((o) => !(o.creatorRole == 'distributor' && !o.isSupplyOrder)).toList();
                        for (var order in filteredOrders) {
                          totalSales += order.finalAmount;
                          totalCollected += order.paidAmount;
                          if (order.remainingAmount > 0) {
                            totalPending += order.remainingAmount;
                          }
                        }
                      }

                      return Column(
                        children: [
                          Row(
                            children: [
                              _summaryCard(
                                'Total Sales',
                                '₹${totalSales.toStringAsFixed(0)}',
                                Icons.insights,
                                const Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 16),
                              _summaryCard(
                                'Total Collected',
                                '₹${totalCollected.toStringAsFixed(0)}',
                                Icons.account_balance_wallet,
                                const Color(0xFF10B981),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _summaryCard(
                                'Total Pending',
                                '₹${totalPending.toStringAsFixed(0)}',
                                Icons.pending_actions,
                                const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(child: SizedBox()),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                  ),
                  const SizedBox(height: 16),

                  _actionCard(
                    title: 'All Orders',
                    subtitle: 'View, search, filter orders, and export PDFs',
                    icon: Icons.receipt_long,
                    color: const Color(0xFF1E3A8A),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                      ).then((_) => RouteTracker.clearRoute());
                    },
                  ),
                  const SizedBox(height: 12),
                  _actionCard(
                    title: 'Reports',
                    subtitle: 'View and export sales & commissions',
                    icon: Icons.analytics,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminReportsScreen()),
                      ).then((_) => RouteTracker.clearRoute());
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
