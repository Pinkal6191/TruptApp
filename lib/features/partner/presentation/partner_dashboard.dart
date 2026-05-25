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
import '../../../core/utils/route_tracker.dart';
import '../../../core/utils/route_restorer.dart';
import '../../../core/models/order_model.dart';
import '../../../core/widgets/sales_trend_graph.dart';
import '../../../core/widgets/crate_sales_breakdown.dart';
import '../../../core/widgets/regular_customers_graph.dart';

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
      context.read<OrderBloc>().add(WatchOrders());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      restoreSavedRoute(context);
    });
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
                    double truptTotalOrders = 0;
                    double truptPendingPayment = 0;
                    
                    int count200ml = 0;
                    int count500ml = 0;
                    int count1L = 0;
                    double rev200ml = 0.0;
                    double rev500ml = 0.0;
                    double rev1L = 0.0;

                    double partnerTotalOrders = 0;
                    double partnerPendingPayment = 0;
                    List<OrderModel> partnerOrders = [];

                    if (state is OrdersLoaded) {
                      for (var o in state.orders) {
                        // Global Company Stats
                        truptTotalOrders += o.finalAmount;
                        if (o.remainingAmount > 0) {
                          truptPendingPayment += o.remainingAmount;
                        }

                        // Crate averages
                        for (var item in o.items) {
                          final name = item.productName.toLowerCase();
                          if (name.contains('200')) {
                            count200ml += item.quantity;
                            rev200ml += item.pricePerCrate * item.quantity;
                          } else if (name.contains('500')) {
                            count500ml += item.quantity;
                            rev500ml += item.pricePerCrate * item.quantity;
                          } else if (name.contains('1l') || name.contains('1 l') || name.contains('1ltr') || name.contains('1 ltr')) {
                            count1L += item.quantity;
                            rev1L += item.pricePerCrate * item.quantity;
                          }
                        }

                        // Partner's own stats
                        if (o.createdBy == user.uid || o.referredPartnerId == user.uid || o.targetUserId == user.uid || o.partnerName == user.name) {
                          partnerOrders.add(o);
                          partnerTotalOrders += o.finalAmount;
                          if (o.remainingAmount > 0) {
                            partnerPendingPayment += o.remainingAmount;
                          }
                        }
                      }
                    }

                    double avg200ml = count200ml > 0 ? (rev200ml / count200ml) : 0.0;
                    double avg500ml = count500ml > 0 ? (rev500ml / count500ml) : 0.0;
                    double avg1L = count1L > 0 ? (rev1L / count1L) : 0.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Trupt Global (Transparency)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _summaryCard('Trupt Total Sales', '₹${truptTotalOrders.toStringAsFixed(0)}', Icons.public, Colors.indigo),
                            const SizedBox(width: 16),
                            _summaryCard('Trupt Pending', '₹${truptPendingPayment.toStringAsFixed(0)}', Icons.account_balance, Colors.redAccent),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text('Trupt Average Price per Crate', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _avgPriceCard('200ml', avg200ml, Colors.blue)),
                            const SizedBox(width: 8),
                            Expanded(child: _avgPriceCard('500ml', avg500ml, Colors.green)),
                            const SizedBox(width: 8),
                            Expanded(child: _avgPriceCard('1L', avg1L, Colors.purple)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 24),

                        const Text('My Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _summaryCard('My Total Sales', '₹${partnerTotalOrders.toStringAsFixed(0)}', Icons.shopping_bag, Colors.blue),
                            const SizedBox(width: 16),
                            _summaryCard('My Pending', '₹${partnerPendingPayment.toStringAsFixed(0)}', Icons.pending_actions, Colors.orange),
                          ],
                        ),
                        if (partnerOrders.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          SalesTrendGraph(orders: partnerOrders),
                          const SizedBox(height: 16),
                          CrateSalesBreakdown(orders: partnerOrders),
                          const SizedBox(height: 16),
                          RegularCustomersGraph(orders: partnerOrders),
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
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen())).then((_) => RouteTracker.clearRoute()),
                ),
                const SizedBox(height: 12),
                _actionCard(
                  title: 'My Custom Prices',
                  subtitle: 'Set your permanent selling prices',
                  icon: Icons.currency_rupee,
                  color: Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomPriceScreen())).then((_) => RouteTracker.clearRoute()),
                ),
                const SizedBox(height: 12),
                _actionCard(
                  title: 'Order History',
                  subtitle: 'Track your previous orders',
                  icon: Icons.history,
                  color: const Color(0xFF64748B),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen())).then((_) => RouteTracker.clearRoute()),
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
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _avgPriceCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text('₹${value.toStringAsFixed(1)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8))),
        ],
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
