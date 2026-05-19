import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../bloc/order_bloc.dart';
import '../bloc/order_event.dart';
import '../bloc/order_state.dart';
import 'order_details_screen.dart';
import '../../../core/models/order_model.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      if (authState.user.role == 'admin') {
        context.read<OrderBloc>().add(LoadOrders()); // Load all for admin
      } else {
        context.read<OrderBloc>().add(LoadOrders(userId: authState.user.uid));
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'paid':
        return const Color(0xFF10B981); // Emerald
      case 'pending':
        return const Color(0xFFF59E0B); // Amber
      case 'dispatched':
      case 'partial':
        return const Color(0xFF3B82F6); // Azure
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Order History'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
      ),
      body: BlocBuilder<OrderBloc, OrderState>(
        builder: (context, state) {
          if (state is OrderLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is OrdersLoaded) {
            final sortedOrders = List<OrderModel>.from(state.orders)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            if (sortedOrders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No orders found',
                      style: TextStyle(fontSize: 20, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }

            final authState = context.read<AuthBloc>().state;
            if (authState is Authenticated && authState.user.role == 'admin') {
              return _buildAdminView(sortedOrders);
            }
            return _buildStandardView(sortedOrders);
          } else if (state is OrderError) {
             return Center(child: Text('Error: ${state.message}', style: const TextStyle(color: Colors.red)));
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildStandardView(List<OrderModel> orders) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)));
          },
          child: Card(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.shopName.isNotEmpty ? order.shopName : order.partnerName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(order.createdAt),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${item.quantity}x ${item.productName}'),
                          Text('₹${(item.quantity * item.pricePerCrate).toStringAsFixed(2)}'),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text(
                      '₹${order.finalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.deliveryStatus).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Delivery: ${order.deliveryStatus}',
                        style: TextStyle(
                          color: _getStatusColor(order.deliveryStatus),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.paymentStatus).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Payment: ${order.paymentStatus}',
                        style: TextStyle(
                          color: _getStatusColor(order.paymentStatus),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (order.deliveryStatus != 'Delivered' || order.paymentStatus != 'Paid') ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (order.deliveryStatus != 'Delivered')
                        TextButton.icon(
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Mark Delivered', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF10B981)),
                          onPressed: () {
                            context.read<OrderBloc>().add(UpdateOrderStatus(orderId: order.id, statusType: 'deliveryStatus', newStatus: 'Delivered'));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as Delivered')));
                          },
                        ),
                      if (order.paymentStatus != 'Paid')
                        TextButton.icon(
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          label: const Text('Mark Paid', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFFF59E0B)),
                          onPressed: () {
                            context.read<OrderBloc>().add(UpdateOrderPayment(orderId: order.id, paidAmount: order.finalAmount, paymentStatus: 'Paid'));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as Paid')));
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildAdminView(List<OrderModel> orders) {
    final partnersOrders = orders.where((o) => o.creatorRole == 'partner').toList();
    final distributorsOrders = orders.where((o) => o.creatorRole == 'distributor').toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF1E3A8A),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF1E3A8A),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Partners'),
              Tab(text: 'Distributors'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildGroupedList(orders),
                _buildGroupedList(partnersOrders),
                _buildGroupedList(distributorsOrders),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return const Center(child: Text('No orders found.'));
    }

    // Group by creator name
    final Map<String, List<OrderModel>> grouped = {};
    for (var order in orders) {
      final name = order.partnerName; // In admin view, partnerName usually reflects the creator/target
      grouped.putIfAbsent(name, () => []).add(order);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final creatorName = grouped.keys.elementAt(index);
        final creatorOrders = grouped[creatorName]!;
        final totalAmount = creatorOrders.fold(0.0, (sum, o) => sum + o.finalAmount);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            title: Text(creatorName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${creatorOrders.length} Orders • Total: ₹${totalAmount.toStringAsFixed(0)}'),
            children: [
              SizedBox(
                height: 300, // Fixed height for nested list to prevent scroll issues, or use shrinkWrap
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: creatorOrders.length,
                  itemBuilder: (context, subIndex) {
                    final order = creatorOrders[subIndex];
                    return ListTile(
                      title: Text(DateFormat('MMM dd, yyyy').format(order.createdAt)),
                      subtitle: Text('Status: ${order.deliveryStatus}'),
                      trailing: Text('₹${order.finalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order))),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
