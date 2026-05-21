import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../orders/presentation/create_order_screen.dart';
import '../../orders/presentation/order_history_screen.dart';
import '../../products/bloc/product_bloc.dart';
import '../../products/bloc/product_event.dart';
import '../../orders/bloc/order_bloc.dart';
import '../../orders/bloc/order_event.dart';
import '../../orders/bloc/order_state.dart';
import '../../products/presentation/custom_price_screen.dart';
import '../../../core/models/order_model.dart';
import '../../../core/widgets/sales_trend_graph.dart';
import '../../../core/widgets/crate_sales_breakdown.dart';

class PartnerDashboard extends StatefulWidget {
  const PartnerDashboard({super.key});

  @override
  State<PartnerDashboard> createState() => _PartnerDashboardState();
}

class _PartnerDashboardState extends State<PartnerDashboard> {
  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<OrderBloc>().add(WatchOrders(
        userId: authState.user.uid,
        userName: authState.user.name,
      ));
    }
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
            title: const Text('Partner Dashboard'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E3A8A),
            elevation: 0,
            actions: [
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user.name}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const Text('Manage your retail orders and payments', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                
                // Summary Cards
                BlocBuilder<OrderBloc, OrderState>(
                  builder: (context, state) {
                    double totalOrders = 0;
                    double pendingPayment = 0;
                    List<OrderModel> partnerOrders = [];
                    if (state is OrdersLoaded) {
                      partnerOrders = state.orders;
                      totalOrders = state.orders.fold(0, (sum, o) => sum + o.finalAmount);
                      pendingPayment = state.orders.fold(0, (sum, o) => sum + (o.finalAmount - o.paidAmount));
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            _summaryCard('Total Orders', '₹${totalOrders.toStringAsFixed(0)}', Icons.shopping_bag, Colors.blue),
                            const SizedBox(width: 16),
                            _summaryCard('Pending', '₹${pendingPayment.toStringAsFixed(0)}', Icons.pending_actions, Colors.orange),
                          ],
                        ),
                        if (partnerOrders.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          SalesTrendGraph(orders: partnerOrders),
                          const SizedBox(height: 16),
                          CrateSalesBreakdown(orders: partnerOrders),
                        ],
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                const SizedBox(height: 16),
                
                _actionCard(
                  title: 'Create New Order',
                  subtitle: 'Place a new product order',
                  icon: Icons.add_shopping_cart,
                  color: const Color(0xFF1E3A8A),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen())),
                ),
                const SizedBox(height: 12),
                _actionCard(
                  title: 'My Custom Prices',
                  subtitle: 'Set your permanent selling prices',
                  icon: Icons.currency_rupee,
                  color: Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomPriceScreen())),
                ),
                const SizedBox(height: 12),
                _actionCard(
                  title: 'Order History',
                  subtitle: 'Track your previous orders',
                  icon: Icons.history,
                  color: const Color(0xFF64748B),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
                ),
              ],
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
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
