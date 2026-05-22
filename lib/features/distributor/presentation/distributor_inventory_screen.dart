import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../../../core/models/inventory_model.dart';
import '../../../core/utils/route_tracker.dart';

class DistributorInventoryScreen extends StatefulWidget {
  const DistributorInventoryScreen({super.key});

  @override
  State<DistributorInventoryScreen> createState() => _DistributorInventoryScreenState();
}

class _DistributorInventoryScreenState extends State<DistributorInventoryScreen> {
  final InventoryRepository _repository = InventoryRepository();

  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('distributor_inventory');
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) return const SizedBox();
        
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('My Inventory'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E3A8A),
            elevation: 0,
          ),
          body: FutureBuilder<List<InventoryModel>>(
            future: _repository.getUserInventory(state.user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final inventory = snapshot.data ?? [];
              if (inventory.isEmpty) {
                return const Center(child: Text('No stock recorded. Orders delivered to you will show up here.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: inventory.length,
                itemBuilder: (context, index) {
                  final item = inventory[index];
                  final bool isLowStock = item.stockCount <= 5;
                  
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isLowStock ? const Color(0xFFEF4444) : const Color(0xFF10B981), 
                        child: Icon(
                          isLowStock ? Icons.warning_amber_rounded : Icons.inventory, 
                          color: Colors.white,
                        ),
                      ),
                      title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        isLowStock ? 'Low Stock! Please order supply' : 'Available Crates',
                        style: TextStyle(
                          color: isLowStock ? const Color(0xFFEF4444) : Colors.grey.shade600,
                          fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Text(
                        '${item.stockCount}',
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          color: isLowStock ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
