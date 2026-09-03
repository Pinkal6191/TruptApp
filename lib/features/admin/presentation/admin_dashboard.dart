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
import '../../../core/utils/route_tracker.dart';
import '../../../core/utils/route_restorer.dart';
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
import 'admin_settings_screen.dart';
import 'admin_partner_expenses_screen.dart';
import 'admin_backup_screen.dart';
import 'scrap_sales_screen.dart';
import '../../inventory/presentation/raw_materials_screen.dart';
import '../../inventory/presentation/production_logs_screen.dart';
import '../../inventory/presentation/factory_inventory_screen.dart';
import '../../inventory/repository/production_repository.dart';
import '../../../core/models/raw_material_model.dart';
import '../../../core/services/database_maintenance_service.dart';
import '../../../core/widgets/sales_trend_graph.dart';
import '../../../core/widgets/regular_customers_graph.dart';
import '../../../core/widgets/crate_sales_breakdown.dart';
import '../../orders/bloc/order_state.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/models/order_model.dart';
import '../../customers/bloc/customer_bloc.dart';
import '../../customers/bloc/customer_event.dart';
import '../../quotations/presentation/quotation_list_screen.dart';
import 'private_label_customers_screen.dart';
import 'private_label_orders_screen.dart';
import 'contract_generator_screen.dart';
import 'contracts_list_screen.dart';
import '../../purchase_orders/presentation/purchase_orders_list_screen.dart';
import 'stock_transfer_screen.dart';
import 'admin_stock_adjustment_screen.dart';


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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      restoreSavedRoute(context);
    });
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
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Customer List',
            onPressed: () => _showSyncCustomersDialog(context),
          ),
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

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ProductBloc>().add(LoadProducts());
              context.read<ExpenseBloc>().add(LoadExpenses());
              context.read<OrderBloc>().add(WatchOrders());
              await Future.delayed(const Duration(milliseconds: 800));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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

                StreamBuilder<List<RawMaterialModel>>(
                  stream: ProductionRepository().watchRawMaterials(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final lowStockItems = snapshot.data!
                          .where((m) => m.stockCount <= m.minReorderLevel)
                          .toList();
                      if (lowStockItems.isNotEmpty) {
                        final names = lowStockItems.map((m) => m.name).join(', ');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RawMaterialsScreen())).then((_) => RouteTracker.clearRoute()),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Low Stock Warning!',
                                        style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'The following raw materials are below minimum levels: $names. Tap to manage.',
                                        style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFEF4444)),
                              ],
                            ),
                          ),
                        );
                      }
                    }
                    return const SizedBox();
                  },
                ),

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
                              ).then((_) => RouteTracker.clearRoute());
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
                const SizedBox(height: 8),
                BlocBuilder<OrderBloc, OrderState>(
                  builder: (context, orderState) {
                    double totalCollected = 0.0;
                    double totalPending = 0.0;
                    double totalSales = 0.0;
                    if (orderState is OrdersLoaded) {
                      final filteredOrders = orderState.orders.where((o) => !(o.creatorRole == 'distributor' && !o.isSupplyOrder)).toList();
                      for (var order in filteredOrders) {
                        totalSales += order.finalAmount;
                        totalCollected += order.paidAmount;
                        // Only count positive remaining as pending; negative = overpaid (change to return)
                        if (order.remainingAmount > 0) {
                          totalPending += order.remainingAmount;
                        }
                      }
                    }
                    return BlocBuilder<ExpenseBloc, ExpenseState>(
                      builder: (context, expenseState) {
                        double totalExpense = 0.0;
                        if (expenseState is ExpensesLoaded) {
                          totalExpense = expenseState.expenses.fold(0.0, (sum, item) => sum + item.amount);
                        }
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('scrap_sales').snapshots(),
                          builder: (context, scrapSnapshot) {
                            double totalScrap = 0.0;
                            if (scrapSnapshot.hasData) {
                              for (var doc in scrapSnapshot.data!.docs) {
                                totalScrap += (doc.data() as Map<String, dynamic>)['amount'] ?? 0.0;
                              }
                            }
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryIndicatorCard(
                                        'Total Sales',
                                        '₹${totalSales.toStringAsFixed(0)}',
                                        Icons.insights,
                                        const Color(0xFF3B82F6),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSummaryIndicatorCard(
                                        'Total Collected',
                                        '₹${totalCollected.toStringAsFixed(0)}',
                                        Icons.account_balance_wallet,
                                        const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryIndicatorCard(
                                        'Total Pending',
                                        '₹${totalPending.toStringAsFixed(0)}',
                                        Icons.pending_actions,
                                        const Color(0xFFF59E0B),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSummaryIndicatorCard(
                                        'Total Expenses',
                                        '₹${totalExpense.toStringAsFixed(0)}',
                                        Icons.receipt_long,
                                        const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryIndicatorCard(
                                        'Scrap Revenue',
                                        '₹${totalScrap.toStringAsFixed(0)}',
                                        Icons.recycling,
                                        Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSummaryIndicatorCard(
                                        'Net Cash in Hand',
                                        '₹${(totalCollected + totalScrap - totalExpense).toStringAsFixed(0)}',
                                        Icons.account_balance,
                                        Colors.indigo,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }
                        );
                      },
                    );
                  },
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
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen())).then((_) => RouteTracker.clearRoute()),
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
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateOrderScreen(isRetailOrder: true))).then((_) => RouteTracker.clearRoute()),
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
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen())).then((_) => RouteTracker.clearRoute()),
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
                        'Stock Transfer Log',
                        'Audit stock sent to distributors',
                        Icons.local_shipping,
                        Colors.teal,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockTransferScreen())).then((_) => RouteTracker.clearRoute()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Stock Adjustment',
                        'Manually correct distributor stock',
                        Icons.tune,
                        Colors.deepOrange,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminStockAdjustmentScreen())).then((_) => RouteTracker.clearRoute()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
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
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductManagementScreen())).then((_) => RouteTracker.clearRoute()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Quotations',
                        'Draft proforma estimates',
                        Icons.request_quote,
                        Colors.cyan.shade700,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuotationListScreen())).then((_) => RouteTracker.clearRoute()),
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
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportsScreen())).then((_) => RouteTracker.clearRoute()),
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
                        'Production',
                        'Log daily batch runs',
                        Icons.precision_manufacturing,
                        Colors.blue,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductionLogsScreen())).then((_) => RouteTracker.clearRoute()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Raw Stock',
                        'Manage raw materials',
                        Icons.science,
                        Colors.teal,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RawMaterialsScreen())).then((_) => RouteTracker.clearRoute()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Factory Stock',
                        'Warehouse stock counts',
                        Icons.warehouse,
                        Colors.deepOrange,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FactoryInventoryScreen())).then((_) => RouteTracker.clearRoute()),
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
                        'Purchase Orders',
                        'Send POs to suppliers',
                        Icons.shopping_cart_checkout,
                        Colors.deepPurple,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrdersListScreen())).then((_) => RouteTracker.clearRoute()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
                    const SizedBox(width: 12),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'Private Label Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                BlocBuilder<OrderBloc, OrderState>(
                  builder: (context, orderState) {
                    double plSales = 0.0;
                    double plCollected = 0.0;
                    double plPending = 0.0;
                    if (orderState is OrdersLoaded) {
                      final filteredOrders = orderState.orders.where((o) => !(o.creatorRole == 'distributor' && !o.isSupplyOrder)).toList();
                      for (var order in filteredOrders) {
                        if (order.orderType == 'private_label') {
                          plSales += order.finalAmount;
                          plCollected += order.paidAmount;
                          if (order.remainingAmount > 0) {
                            plPending += order.remainingAmount;
                          }
                        }
                      }
                    }
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryIndicatorCard(
                                'PL Sales',
                                '₹${plSales.toStringAsFixed(0)}',
                                Icons.insights,
                                const Color(0xFF3B82F6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSummaryIndicatorCard(
                                'PL Collected',
                                '₹${plCollected.toStringAsFixed(0)}',
                                Icons.account_balance_wallet,
                                const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSummaryIndicatorCard(
                                'PL Pending',
                                '₹${plPending.toStringAsFixed(0)}',
                                Icons.pending_actions,
                                const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Custom Customers',
                        'Manage Private Label clients',
                        Icons.storefront,
                        Colors.pink,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivateLabelCustomersScreen())).then((_) => RouteTracker.clearRoute()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Custom Orders',
                        'View custom bottle orders',
                        Icons.local_shipping,
                        Colors.deepPurple,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivateLabelOrdersScreen())).then((_) => RouteTracker.clearRoute()),
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
                        'Generate Contract',
                        'Draft formal agreements',
                        Icons.document_scanner,
                        Colors.blueGrey,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractGeneratorScreen())).then((_) => RouteTracker.clearRoute()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        'Saved Contracts',
                        'View, edit, or delete contracts',
                        Icons.folder_shared,
                        Colors.brown,
                        () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContractsListScreen())).then((_) => RouteTracker.clearRoute()),
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
                      final filteredOrders = orderState.orders.where((o) => !(o.creatorRole == 'distributor' && !o.isSupplyOrder)).toList();
                      return Column(
                        children: [
                          SalesTrendGraph(orders: filteredOrders),
                          const SizedBox(height: 16),
                          CrateSalesBreakdown(orders: filteredOrders),
                          const SizedBox(height: 16),
                          RegularCustomersGraph(orders: filteredOrders),
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
                
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.cloud_download, color: Colors.white)),
                    title: const Text('Data Backup & Export'),
                    subtitle: const Text('Download a complete backup of all database records'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBackupScreen())).then((_) => RouteTracker.clearRoute()),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.recycling, color: Colors.white)),
                    title: const Text('Scrap (Bhangar) Sales'),
                    subtitle: const Text('Log and view revenue from sold factory waste'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScrapSalesScreen())).then((_) => RouteTracker.clearRoute()),
                  ),
                ),
                const SizedBox(height: 12),

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
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseManagementScreen())).then((_) => RouteTracker.clearRoute()),
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
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen())).then((_) => RouteTracker.clearRoute()),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.receipt_long, color: Colors.white)),
                    title: const Text('Partner Expenses'),
                    subtitle: const Text('Review and approve partner delivery expenses'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPartnerExpensesScreen())).then((_) => RouteTracker.clearRoute()),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.settings, color: Colors.white)),
                    title: const Text('System Settings'),
                    subtitle: const Text('Configure global rates and policies'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen())).then((_) => RouteTracker.clearRoute()),
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
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())).then((_) => RouteTracker.clearRoute()),
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

  void _showSyncCustomersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Customer List'),
        content: const Text(
          'This will analyze all historical orders, reconstruct the customer directory, '
          'and recalculate total orders and spending metrics per customer. '
          'No existing orders will be modified or deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _runCustomerMigration();
            },
            child: const Text('Sync Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _runCustomerMigration() async {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Starting Customer Directory Sync & Deduplication...')),
    );

    try {
      final ordersSnapshot = await FirebaseFirestore.instance.collection('orders').get();
      final customersSnapshot = await FirebaseFirestore.instance.collection('customers').get();

      final List<CustomerModel> existingCustomers = customersSnapshot.docs.map((doc) {
        return CustomerModel.fromMap(doc.data(), doc.id);
      }).toList();

      final retailOrders = ordersSnapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where((order) => !order.isSupplyOrder)
          .toList();

      final List<CustomerModel> processedCustomers = [];
      final List<String> deletedCustomerIds = [];

      bool matches(CustomerModel c, OrderModel order) {
        final shopMatch = c.shopName.toLowerCase().trim().isNotEmpty &&
            order.shopName.toLowerCase().trim().isNotEmpty &&
            c.shopName.toLowerCase().trim() == order.shopName.toLowerCase().trim();
        if (shopMatch) return true;

        final mobileMatch = c.mobileNumber.trim().isNotEmpty &&
            order.customerMobile.trim().isNotEmpty &&
            c.mobileNumber.trim() == order.customerMobile.trim();
        if (mobileMatch) return true;

        return false;
      }

      bool matchesCustomer(CustomerModel c1, CustomerModel c2) {
        final shopMatch = c1.shopName.toLowerCase().trim().isNotEmpty &&
            c2.shopName.toLowerCase().trim().isNotEmpty &&
            c1.shopName.toLowerCase().trim() == c2.shopName.toLowerCase().trim();
        if (shopMatch) return true;

        final mobileMatch = c1.mobileNumber.trim().isNotEmpty &&
            c2.mobileNumber.trim().isNotEmpty &&
            c1.mobileNumber.trim() == c2.mobileNumber.trim();
        if (mobileMatch) return true;

        return false;
      }

      for (var order in retailOrders) {
        int processedIndex = processedCustomers.indexWhere((c) => matches(c, order));

        if (processedIndex != -1) {
          final current = processedCustomers[processedIndex];
          
          String address = current.address.trim().isEmpty ? order.customerAddress.trim() : current.address;
          String gst = current.gstNumber.trim().isEmpty ? order.customerGstNumber.trim() : current.gstNumber;
          String partner = current.partnerId.trim().isEmpty ? 
              (order.referredPartnerId.isNotEmpty ? order.referredPartnerId : order.createdBy) : current.partnerId;

          processedCustomers[processedIndex] = CustomerModel(
            id: current.id,
            shopName: current.shopName,
            mobileNumber: current.mobileNumber,
            address: address,
            gstNumber: gst,
            partnerId: partner,
            totalOrders: current.totalOrders + 1,
            totalAmountSpent: current.totalAmountSpent + order.finalAmount,
            isPrivateLabel: current.isPrivateLabel,
            createdAt: current.createdAt.isBefore(order.createdAt) ? current.createdAt : order.createdAt,
          );
        } else {
          // Find all matching existing customers
          final List<int> matchingIndices = [];
          for (int i = 0; i < existingCustomers.length; i++) {
            if (matches(existingCustomers[i], order)) {
              matchingIndices.add(i);
            }
          }

          if (matchingIndices.isNotEmpty) {
            final ext = existingCustomers[matchingIndices[0]];
            
            String address = ext.address.trim().isEmpty ? order.customerAddress.trim() : ext.address;
            String gst = ext.gstNumber.trim().isEmpty ? order.customerGstNumber.trim() : ext.gstNumber;
            String partner = ext.partnerId.trim().isEmpty ? 
                (order.referredPartnerId.isNotEmpty ? order.referredPartnerId : order.createdBy) : ext.partnerId;

            processedCustomers.add(CustomerModel(
              id: ext.id,
              shopName: order.shopName.trim().isNotEmpty ? order.shopName.trim() : ext.shopName,
              mobileNumber: order.customerMobile.trim().isNotEmpty ? order.customerMobile.trim() : ext.mobileNumber,
              address: address,
              gstNumber: gst,
              partnerId: partner,
              totalOrders: 1,
              totalAmountSpent: order.finalAmount,
              isPrivateLabel: ext.isPrivateLabel,
              createdAt: ext.createdAt.isBefore(order.createdAt) ? ext.createdAt : order.createdAt,
            ));

            // Mark duplicate existing customers for deletion
            for (int i = 1; i < matchingIndices.length; i++) {
              deletedCustomerIds.add(existingCustomers[matchingIndices[i]].id);
            }
          } else {
            final newId = FirebaseFirestore.instance.collection('customers').doc().id;
            final partner = order.referredPartnerId.isNotEmpty 
                ? order.referredPartnerId 
                : (order.createdBy.isNotEmpty ? order.createdBy : 'admin');

            processedCustomers.add(CustomerModel(
              id: newId,
              shopName: order.shopName.trim(),
              mobileNumber: order.customerMobile.trim(),
              address: order.customerAddress.trim(),
              gstNumber: order.customerGstNumber.trim(),
              partnerId: partner,
              totalOrders: 1,
              totalAmountSpent: order.finalAmount,
              isPrivateLabel: order.orderType == 'private_label',
              createdAt: order.createdAt,
            ));
          }
        }
      }

      // Add unmatched existing customers, but filter out duplicates
      for (var ext in existingCustomers) {
        if (processedCustomers.any((c) => c.id == ext.id) || deletedCustomerIds.contains(ext.id)) {
          continue;
        }

        // Check if this unmatched customer matches any customer in processedCustomers
        bool isDupe = processedCustomers.any((c) => matchesCustomer(c, ext));
        if (isDupe) {
          deletedCustomerIds.add(ext.id);
        } else {
          processedCustomers.add(ext);
        }
      }

      final firestore = FirebaseFirestore.instance;
      int chunkCount = 0;
      WriteBatch batch = firestore.batch();

      // Write unique/updated customers
      for (var customer in processedCustomers) {
        final docRef = firestore.collection('customers').doc(customer.id);
        batch.set(docRef, customer.toMap());
        chunkCount++;

        if (chunkCount >= 200) {
          await batch.commit();
          batch = firestore.batch();
          chunkCount = 0;
        }
      }
      
      // Delete duplicate customers
      for (var id in deletedCustomerIds) {
        final docRef = firestore.collection('customers').doc(id);
        batch.delete(docRef);
        chunkCount++;

        if (chunkCount >= 200) {
          await batch.commit();
          batch = firestore.batch();
          chunkCount = 0;
        }
      }
      
      if (chunkCount > 0) {
        await batch.commit();
      }

      if (mounted) {
        context.read<CustomerBloc>().add(LoadCustomers());
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync complete! Found ${processedCustomers.length} unique customers. Cleaned ${deletedCustomerIds.length} duplicates.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
