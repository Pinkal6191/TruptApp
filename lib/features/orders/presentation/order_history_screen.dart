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
  String _statusFilter = 'All'; // 'All', 'Pending'
  int _currentPage = 1;
  static const int _pageSize = 20;

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
            final authState = context.read<AuthBloc>().state;
            final bool isAdmin = authState is Authenticated && authState.user.role == 'admin';
            final String? currentUserId = authState is Authenticated ? authState.user.uid : null;
            final String? currentUserName = authState is Authenticated ? authState.user.name : null;

            var sortedOrders = List<OrderModel>.from(state.orders)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            
            if (!isAdmin && currentUserId != null) {
              sortedOrders = sortedOrders.where((o) => 
                o.createdBy == currentUserId || 
                o.referredPartnerId == currentUserId || 
                o.targetUserId == currentUserId || 
                o.partnerName == currentUserName
              ).toList();
            }

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
              // 1. Search Query filter
              if (query.isNotEmpty) {
                final matchShop = order.shopName.toLowerCase().contains(query);
                final matchPartner = order.partnerName.toLowerCase().contains(query);
                final matchRef = order.orderReference.toLowerCase().contains(query);
                final matchInvoice = order.invoiceNumber.toLowerCase().contains(query);
                final matchProducts = order.items.any((item) => item.productName.toLowerCase().contains(query));
                if (!matchShop && !matchPartner && !matchRef && !matchInvoice && !matchProducts) {
                  return false;
                }
              }

              // 2. Status filter (Pending Delivery OR Pending Payment)
              if (_statusFilter == 'Pending') {
                final isPendingDelivery = order.deliveryStatus.toLowerCase() != 'delivered';
                final isPendingPayment = order.paymentStatus.toLowerCase() != 'paid';
                return isPendingDelivery || isPendingPayment;
              }

              return true;
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _currentPage = 1;
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Orders'),
                        selected: _statusFilter == 'All',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _statusFilter = 'All';
                              _currentPage = 1;
                            });
                          }
                        },
                        selectedColor: const Color(0xFFEFF6FF),
                        checkmarkColor: const Color(0xFF1E3A8A),
                        labelStyle: TextStyle(
                          color: _statusFilter == 'All' ? const Color(0xFF1E3A8A) : Colors.grey.shade600,
                          fontWeight: _statusFilter == 'All' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(
                          color: _statusFilter == 'All' ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Pending Orders'),
                        selected: _statusFilter == 'Pending',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _statusFilter = 'Pending';
                              _currentPage = 1;
                            });
                          }
                        },
                        selectedColor: const Color(0xFFFEF3C7),
                        checkmarkColor: const Color(0xFFD97706),
                        labelStyle: TextStyle(
                          color: _statusFilter == 'Pending' ? const Color(0xFFB45309) : Colors.grey.shade600,
                          fontWeight: _statusFilter == 'Pending' ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide(
                          color: _statusFilter == 'Pending' ? const Color(0xFFFBBF24).withValues(alpha: 0.5) : Colors.grey.shade300,
                        ),
                      ),
                    ],
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
    final totalItems = orders.length;
    final totalPages = (totalItems / _pageSize).ceil();
    
    // Adjust current page if it is out of bounds due to filtering
    int page = _currentPage;
    if (page > totalPages && totalPages > 0) {
      page = totalPages;
    }
    
    final paginated = orders.skip((page - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        // Count banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Showing ${totalItems > 0 ? (page - 1) * _pageSize + 1 : 0} - ${(page * _pageSize) < totalItems ? (page * _pageSize) : totalItems} of $totalItems order${totalItems == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: paginated.length,
            itemBuilder: (context, index) {
              final order = paginated[index];
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
                      if (order.referredPartnerId.isNotEmpty && order.creatorRole == 'admin') ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.handshake_outlined, size: 12, color: Colors.indigo.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '🤝 Referred by Admin',
                              style: TextStyle(fontSize: 12, color: Colors.indigo.shade600, fontWeight: FontWeight.w600),
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
                          const Spacer(),
                          if (order.remainingAmount < 0)
                            _adminAmountBadge('Return ₹${order.remainingAmount.abs().toStringAsFixed(0)}', Colors.purple.shade600, Colors.purple.shade50)
                          else if (order.remainingAmount > 0)
                            _adminAmountBadge('Due ₹${order.remainingAmount.toStringAsFixed(0)}', Colors.red.shade700, Colors.red.shade50)
                          else
                            _adminAmountBadge('Fully Paid ✓', Colors.green.shade700, Colors.green.shade50),
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
          ),
        ),
        _buildPaginationControls(totalPages),
      ],
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

    // Group by effective partner name.
    // Priority: if the order has a referredPartnerId, use orderReference
    // (which is always stored as the partner's actual name at creation time).
    // This fixes older orders where partnerName was stored as admin's name
    // even though the credit belongs to a referred partner.
    final Map<String, List<OrderModel>> grouped = {};
    for (var order in orders) {
      final String name = (order.referredPartnerId.isNotEmpty &&
              order.orderReference.isNotEmpty &&
              order.orderReference != 'Direct (Online / Call)')
          ? order.orderReference
          : order.partnerName;
      grouped.putIfAbsent(name, () => []).add(order);
    }

    final totalItems = grouped.keys.length;
    final totalPages = (totalItems / _pageSize).ceil();
    int page = _currentPage;
    if (page > totalPages && totalPages > 0) {
      page = totalPages;
    }
    if (page < 1) page = 1;

    final paginatedKeys = grouped.keys.skip((page - 1) * _pageSize).take(_pageSize).toList();

    return Column(
      children: [
        if (totalItems > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Showing ${totalItems > 0 ? (page - 1) * _pageSize + 1 : 0} - ${(page * _pageSize) < totalItems ? (page * _pageSize) : totalItems} of $totalItems group${totalItems == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: paginatedKeys.length,
            itemBuilder: (context, index) {
              final creatorName = paginatedKeys[index];
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
          ),
        ),
        _buildPaginationControls(totalPages),
      ],
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton.icon(
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text('Prev', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF1E3A8A),
              disabledBackgroundColor: Colors.grey.shade100,
              disabledForegroundColor: Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: _currentPage > 1 ? const Color(0xFF3B82F6).withValues(alpha: 0.2) : Colors.transparent,
                ),
              ),
            ),
          ),
          Text(
            'Page $_currentPage of $totalPages',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          ElevatedButton(
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFFEFF6FF),
              foregroundColor: const Color(0xFF1E3A8A),
              disabledBackgroundColor: Colors.grey.shade100,
              disabledForegroundColor: Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: _currentPage < totalPages ? const Color(0xFF3B82F6).withValues(alpha: 0.2) : Colors.transparent,
                ),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Next', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
