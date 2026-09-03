import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';
import '../../inventory/repository/inventory_repository.dart';
import '../../../core/models/inventory_model.dart';

class AdminStockAdjustmentScreen extends StatefulWidget {
  const AdminStockAdjustmentScreen({super.key});

  @override
  State<AdminStockAdjustmentScreen> createState() => _AdminStockAdjustmentScreenState();
}

class _AdminStockAdjustmentScreenState extends State<AdminStockAdjustmentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final InventoryRepository _inventoryRepository = InventoryRepository();

  bool _isLoading = true;
  List<UserModel> _distributors = [];
  UserModel? _selectedDistributor;
  List<InventoryModel> _inventory = [];
  bool _loadingInventory = false;

  @override
  void initState() {
    super.initState();
    _loadDistributors();
  }

  Future<void> _loadDistributors() async {
    try {
      final snap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'distributor')
          .where('isApproved', isEqualTo: true)
          .get();
      setState(() {
        _distributors = snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInventory(String userId) async {
    setState(() { _loadingInventory = true; _inventory = []; });
    try {
      final inv = await _inventoryRepository.getUserInventory(userId);
      setState(() { _inventory = inv; _loadingInventory = false; });
    } catch (e) {
      setState(() => _loadingInventory = false);
    }
  }

  Future<void> _showAdjustDialog(InventoryModel item) async {
    final controller = TextEditingController();
    String mode = 'add'; // 'add' or 'subtract'

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Adjust Stock: ${item.productName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Stock: ${item.stockCount} crates',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),

              // Add / Subtract toggle
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setStateDialog(() => mode = 'add'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: mode == 'add' ? const Color(0xFF10B981) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: mode == 'add' ? const Color(0xFF10B981) : Colors.grey.shade300),
                        ),
                        child: Text(
                          '➕ Add',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: mode == 'add' ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setStateDialog(() => mode = 'subtract'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: mode == 'subtract' ? Colors.red : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: mode == 'subtract' ? Colors.red : Colors.grey.shade300),
                        ),
                        child: Text(
                          '➖ Subtract',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: mode == 'subtract' ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity (crates)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.inventory),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    if (result == true && _selectedDistributor != null) {
      final qty = int.tryParse(controller.text.trim());
      if (qty == null || qty <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid quantity'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final adjustment = mode == 'add' ? qty : -qty;

      try {
        await _inventoryRepository.updateStock(
          _selectedDistributor!.uid,
          item.productId,
          item.productName,
          adjustment,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${mode == "add" ? "Added" : "Subtracted"} $qty crates of ${item.productName} successfully!',
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }

        // Reload inventory
        await _loadInventory(_selectedDistributor!.uid);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Stock Adjustment'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFFBEB),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Use this to manually correct stock discrepancies. Select a distributor, then tap any product to adjust.',
                          style: TextStyle(fontSize: 13, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<UserModel>(
                    value: _selectedDistributor,
                    decoration: InputDecoration(
                      labelText: 'Select Distributor',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _distributors.map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d.name),
                    )).toList(),
                    onChanged: (d) {
                      setState(() => _selectedDistributor = d);
                      if (d != null) _loadInventory(d.uid);
                    },
                  ),
                ),

                if (_selectedDistributor != null) ...[
                  if (_loadingInventory)
                    const Center(child: CircularProgressIndicator())
                  else if (_inventory.isEmpty)
                    const Expanded(
                      child: Center(child: Text('No stock found for this distributor.', style: TextStyle(color: Colors.grey))),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _inventory.length,
                        itemBuilder: (context, index) {
                          final item = _inventory[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 1.5,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                                child: const Icon(Icons.inventory_2, color: Color(0xFF1E3A8A)),
                              ),
                              title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              subtitle: const Text('Tap to adjust'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${item.stockCount}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('crates', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.edit, color: Colors.grey, size: 18),
                                ],
                              ),
                              onTap: () => _showAdjustDialog(item),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
