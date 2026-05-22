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
import '../../../core/utils/route_tracker.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('order_history');
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      if (authState.user.role == 'admin') {
        context.read<OrderBloc>().add(LoadOrders()); // Load all for admin
      } else {
        context.read<OrderBloc>().add(LoadOrders(
          userId: authState.user.uid,
          userName: authState.user.name,
        ));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Color _deliveryColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return const Color(0xFF10B981); // Emerald
      case 'dispatched':
        return const Color(0xFF3B82F6); // Azure
      case 'pending':
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  Color _paymentColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFF10B981); // Emerald
      case 'partial':
        return const Color(0xFF3B82F6); // Azure
      case 'pending':
      default:
        return const Color(0xFFEF4444); // Red/Amber
    }
  }

  Widget _adminStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _adminAmountBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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

            final query = _searchQuery.toLowerCase().trim();
            final filteredOrders = sortedOrders.where((order) {
              if (query.isEmpty) return true;
              final matchShop = order.shopName.toLowerCase().contains(query);
              final matchPartner = order.partnerName.toLowerCase().contains(query);
              final matchRef = order.orderReference.toLowerCase().contains(query);
              final matchInvoice = order.invoiceNumber.toLowerCase().contains(query);
              final matchProducts = order.items.any((item) => item.productName.toLowerCase().contains(query));
              return matchShop || matchPartner || matchRef || matchInvoice || matchProducts;
            }).toList();

            final authState = context.read<AuthBloc>().state;
            final bool isAdmin = authState is Authenticated && authState.user.role == 'admin';

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by customer, partner, ref, invoice, or product...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A8A)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
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
                Expanded(
                  child: filteredOrders.isEmpty
                      ? const Center(child: Text('No matching orders found.'))
                      : (isAdmin
                          ? _buildAdminView(filteredOrders)
                          : _buildStandardView(filteredOrders)),
                ),
              ],
            );
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
            Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)))
                .then((_) => RouteTracker.saveRoute('order_history'));
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
                    Expanded(
                      child: Text(
                        order.shopName.isNotEmpty ? order.shopName : order.partnerName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, yyyy').format(order.createdAt),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                if (order.creatorRole == 'admin') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 12, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Ref: ${order.orderReference}',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity}x ${item.productName}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  children: [
                    // Delete Button
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete Order',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final authState = context.read<AuthBloc>().state;
                        final userId = authState is Authenticated && authState.user.role != 'admin' ? authState.user.uid : null;
                        final userName = authState is Authenticated && authState.user.role != 'admin' ? authState.user.name : null;
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Delete Order'),
                            content: const Text('Are you sure you want to delete this order? This will also reverse all stock changes associated with this order.'),
                            actions: [
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () => Navigator.pop(dialogContext),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                onPressed: () {
                                  context.read<OrderBloc>().add(DeleteOrder(
                                        order: order,
                                        userId: userId,
                                        userName: userName,
                                      ));
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Deleting order...')),
                                  );
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    if (order.deliveryStatus != 'Delivered')
                      TextButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Mark Delivered', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF10B981)),
                        onPressed: () {
                          final authState = context.read<AuthBloc>().state;
                          final userId = authState is Authenticated && authState.user.role != 'admin' ? authState.user.uid : null;
                          final userName = authState is Authenticated && authState.user.role != 'admin' ? authState.user.name : null;
                          context.read<OrderBloc>().add(UpdateOrderStatus(
                                orderId: order.id,
                                statusType: 'deliveryStatus',
                                newStatus: 'Delivered',
                                userId: userId,
                                userName: userName,
                              ));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as Delivered')));
                        },
                      ),
                    const SizedBox(width: 8),
                    if (order.paymentStatus != 'Paid')
                      TextButton.icon(
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: const Text('Mark Paid', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFF59E0B)),
                        onPressed: () {
                          final authState = context.read<AuthBloc>().state;
                          final userId = authState is Authenticated && authState.user.role != 'admin' ? authState.user.uid : null;
                          final userName = authState is Authenticated && authState.user.role != 'admin' ? authState.user.name : null;
                          context.read<OrderBloc>().add(UpdateOrderPayment(
                                orderId: order.id,
                                paidAmount: order.finalAmount,
                                paymentStatus: 'Paid',
                                userId: userId,
                                userName: userName,
                              ));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as Paid')));
                        },
                      )
                    else
                      TextButton.icon(
                        icon: const Icon(Icons.money_off_outlined, size: 16),
                        label: const Text('Mark Unpaid', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () {
                          final authState = context.read<AuthBloc>().state;
                          final userId = authState is Authenticated && authState.user.role != 'admin' ? authState.user.uid : null;
                          final userName = authState is Authenticated && authState.user.role != 'admin' ? authState.user.name : null;
                          context.read<OrderBloc>().add(UpdateOrderPayment(
                                orderId: order.id,
                                paidAmount: 0.0,
                                paymentStatus: 'Pending',
                                userId: userId,
                                userName: userName,
                              ));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as Pending (Unpaid)')));
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildAdminView(List<OrderModel> orders) {
    // Partners tab: orders by partners OR admin orders with a partner reference
    final partnersOrders = orders.where((o) =>
      o.creatorRole == 'partner' ||
      (o.creatorRole == 'admin' && o.orderReference != 'Direct (Online / Call)')
    ).toList();

    // Distributors tab: orders by distributors OR admin supply orders sent to distributors
    final distributorsOrders = orders.where((o) =>
      o.creatorRole == 'distributor' ||
      (o.creatorRole == 'admin' && o.isSupplyOrder)
    ).toList();

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

    // Group by partnerName
    final Map<String, List<OrderModel>> grouped = {};
    for (var order in orders) {
      final name = order.partnerName;
      grouped.putIfAbsent(name, () => []).add(order);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final creatorName = grouped.keys.elementAt(index);
        final creatorOrders = grouped[creatorName]!;
        final totalAmount = creatorOrders.fold(0.0, (sum, o) => sum + o.finalAmount);
        final totalPending = creatorOrders.fold(0.0, (sum, o) => sum + (o.remainingAmount > 0 ? o.remainingAmount : 0.0));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            title: Text(creatorName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Text('${creatorOrders.length} Orders • ₹${totalAmount.toStringAsFixed(0)}'),
                if (totalPending > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Pending ₹${totalPending.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: creatorOrders.length,
                itemBuilder: (context, subIndex) {
                  final order = creatorOrders[subIndex];
                  final customerDisplay = order.shopName.isNotEmpty ? order.shopName : '(No Shop Name)';
                  final pending = order.remainingAmount;
                  final isOverpaid = pending < 0;

                  return InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)))
                          .then((_) => RouteTracker.saveRoute('order_history'));
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Customer/Shop name + Bill amount
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  customerDisplay,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '₹${order.finalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E3A8A)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Row 2: Date + Invoice number
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd MMM yyyy').format(order.createdAt),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              if (order.invoiceNumber.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Icon(Icons.receipt_outlined, size: 12, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  '#${order.invoiceNumber}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Row 3: Delivery + Payment status badges + Due/Paid badge
                          Row(
                            children: [
                              _adminStatusBadge(order.deliveryStatus, _deliveryColor(order.deliveryStatus)),
                              const SizedBox(width: 6),
                              _adminStatusBadge(order.paymentStatus, _paymentColor(order.paymentStatus)),
                              const Spacer(),
                              if (isOverpaid)
                                _adminAmountBadge('Return ₹${pending.abs().toStringAsFixed(0)}', Colors.purple.shade600, Colors.purple.shade50)
                              else if (pending > 0)
                                _adminAmountBadge('Due ₹${pending.toStringAsFixed(0)}', Colors.red.shade700, Colors.red.shade50)
                              else
                                _adminAmountBadge('Fully Paid ✓', Colors.green.shade700, Colors.green.shade50),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
