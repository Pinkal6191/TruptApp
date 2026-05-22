import 'package:flutter/material.dart';
import 'route_tracker.dart';
import '../../features/orders/presentation/order_history_screen.dart';
import '../../features/orders/presentation/order_details_screen.dart';

// Import all potential target screens
import '../../features/admin/presentation/product_management_screen.dart';
import '../../features/admin/presentation/admin_reports_screen.dart';
import '../../features/admin/presentation/user_management_screen.dart';
import '../../features/admin/presentation/customer_list_screen.dart';
import '../../features/admin/presentation/user_approval_screen.dart';
import '../../features/orders/presentation/create_order_screen.dart';
import '../../features/inventory/presentation/raw_materials_screen.dart';
import '../../features/inventory/presentation/production_logs_screen.dart';
import '../../features/inventory/presentation/factory_inventory_screen.dart';
import '../../features/expenses/presentation/expense_management_screen.dart';
import '../../features/products/presentation/custom_price_screen.dart';
import '../../features/distributor/presentation/distributor_inventory_screen.dart';

Future<bool> restoreSavedRoute(BuildContext context) async {
  final saved = await RouteTracker.getSavedRoute();
  if (saved == null || !context.mounted) {
    RouteTracker.clearRoute();
    return false;
  }

  final String name = saved['name'];
  final Map<String, dynamic>? data = saved['data'];

  Widget? screen;
  if (name == 'order_history') {
    screen = const OrderHistoryScreen();
  } else if (name == 'order_details' && data != null && data['orderId'] != null) {
    screen = OrderDetailsRestoreLoader(orderId: data['orderId']);
  } else if (name == 'user_approval') {
    screen = const UserApprovalScreen();
  } else if (name == 'create_order') {
    final bool isRetail = data?['isRetailOrder'] ?? false;
    final String? extId = data?['existingOrderId'];
    screen = CreateOrderRestoreLoader(isRetailOrder: isRetail, existingOrderId: extId);
  } else if (name == 'product_management') {
    screen = const ProductManagementScreen();
  } else if (name == 'admin_reports') {
    screen = const AdminReportsScreen();
  } else if (name == 'user_management') {
    screen = const UserManagementScreen();
  } else if (name == 'customer_list') {
    screen = const CustomerListScreen();
  } else if (name == 'raw_materials') {
    screen = const RawMaterialsScreen();
  } else if (name == 'production_logs') {
    screen = const ProductionLogsScreen();
  } else if (name == 'factory_inventory') {
    screen = const FactoryInventoryScreen();
  } else if (name == 'expense_management') {
    screen = const ExpenseManagementScreen();
  } else if (name == 'custom_price') {
    screen = const CustomPriceScreen();
  } else if (name == 'distributor_inventory') {
    screen = const DistributorInventoryScreen();
  }

  if (screen != null && context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen!),
    ).then((_) {
      RouteTracker.clearRoute();
    });
    return true;
  }
  
  RouteTracker.clearRoute();
  return false;
}

