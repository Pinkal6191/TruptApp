import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../orders/presentation/create_order_screen.dart';
import '../../orders/presentation/order_history_screen.dart';
import '../../orders/bloc/order_bloc.dart';
import '../../orders/bloc/order_event.dart';
import '../../orders/bloc/order_state.dart';
import '../../products/bloc/product_bloc.dart';
import '../../products/bloc/product_event.dart';
import '../../inventory/bloc/inventory_bloc.dart';
import '../../products/presentation/custom_price_screen.dart';
import 'distributor_inventory_screen.dart';
import '../../../core/widgets/sales_trend_graph.dart';
import '../../../core/widgets/crate_sales_breakdown.dart';

class DistributorDashboard extends StatefulWidget {
  const DistributorDashboard({super.key});

  @override
  State<DistributorDashboard> createState() => _DistributorDashboardState();
}

class _DistributorDashboardState extends State<DistributorDashboard> {
  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<OrderBloc>().add(WatchOrders(userId: authState.user.uid));
      context.read<InventoryBloc>().add(WatchInventory(authState.user.uid));
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
            title: const Text('Distributor Dashboard'),
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
                const Text('Manage your supply chain and commissions', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),
                
                // Summary Cards
                BlocBuilder<OrderBloc, OrderState>(
                  builder: (context, state) {
                    double totalSales = 0;
                    double totalCommission = 0;
                    if (state is OrdersLoaded) {
                      totalSales = state.orders.fold(0, (sum, o) => sum + o.finalAmount);
                      // Commission calculation: (Actual Sell Price - Distributor Cost) * Quantity
                      for (var order in state.orders) {
                        for (var item in order.items) {
                          if (item.pricePerCrate > item.distributorCost && item.distributorCost > 0) {
                            totalCommission += ((item.pricePerCrate - item.distributorCost) * item.quantity);
                          }
                        }
                      }
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            _summaryCard('My Sales', '₹${totalSales.toStringAsFixed(0)}', Icons.payments, Colors.green),
                            const SizedBox(width: 16),
                            _summaryCard('My Commission', '₹${totalCommission.toStringAsFixed(0)}', Icons.account_balance, Colors.indigo),
                          ],
                        ),
                        const SizedBox(height: 16),
                        BlocBuilder<InventoryBloc, InventoryState>(
                          builder: (context, invState) {
                            int totalCrates = 0;
                            if (invState is InventoryLoaded) {
                              totalCrates = invState.inventory.fold(0, (sum, i) => sum + i.stockCount);
                            }
                            return _summaryCard('Current Stock', '$totalCrates Crates', Icons.inventory, Colors.orange, isFullWidth: true);
                          },
                        ),
                        if (state is OrdersLoaded && state.orders.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          SalesTrendGraph(orders: state.orders),
                          const SizedBox(height: 16),
                          CrateSalesBreakdown(orders: state.orders),
                        ],
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                const Text('Operations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                const SizedBox(height: 16),
                
                _actionCard(
                  title: 'Create Order (Sell)',
                  subtitle: 'Register a sale to a Retailer',
                  icon: Icons.add_shopping_cart,
                  color: const Color(0xFF1E3A8A),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen())),
                ),
                const SizedBox(height: 12),
                _actionCard(
                  title: 'My Stock / Inventory',
                  subtitle: 'Manage your local crate storage',
                  icon: Icons.inventory_2,
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DistributorInventoryScreen())),
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
                  title: 'Sales History',
                  subtitle: 'View your previous transactions',
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

  Widget _summaryCard(String title, String value, IconData icon, Color color, {bool isFullWidth = false}) {
    final card = Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      );

    return isFullWidth ? card : Expanded(child: card);
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
