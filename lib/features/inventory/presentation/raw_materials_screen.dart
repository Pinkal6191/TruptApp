import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/raw_material_model.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/utils/route_tracker.dart';
import '../repository/production_repository.dart';
import '../../expenses/repository/expense_repository.dart';

class RawMaterialsScreen extends StatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  State<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends State<RawMaterialsScreen> {
  final ProductionRepository _productionRepository = ProductionRepository();
  final ExpenseRepository _expenseRepository = ExpenseRepository();

  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('raw_materials');
  }

  void _showMaterialModal({RawMaterialModel? material}) {
    final isEditing = material != null;
    final nameController = TextEditingController(text: material?.name ?? '');
    final minReorderController = TextEditingController(text: material != null ? material.minReorderLevel.toString() : '10.0');
    final stockController = TextEditingController(text: material != null ? material.stockCount.toString() : '0.0');
    final purchaseCostController = TextEditingController();
    final transportCostController = TextEditingController();
    String selectedUnit = material?.unit ?? 'kg';

    final List<String> commonUnits = ['kg', 'liters', 'pcs', 'bags', 'grams', 'ml'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Raw Material' : 'Add Raw Material',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Material Name',
                        hintText: 'e.g. Sugar, Bottles, Caps, Flavor',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: commonUnits.contains(selectedUnit) ? selectedUnit : commonUnits.first,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: commonUnits.map((String val) {
                              return DropdownMenuItem(value: val, child: Text(val));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => selectedUnit = val);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: minReorderController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Min Reorder Level',
                              hintText: 'e.g. 50.0',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isEditing) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setModalState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Initial Stock Count',
                                hintText: 'e.g. 100.0',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: purchaseCostController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setModalState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Purchase Cost (₹)',
                                hintText: 'Optional',
                                border: OutlineInputBorder(),
                                prefixText: '₹ ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: transportCostController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Transport Cost (₹)',
                          hintText: 'Optional Transport cost',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                          prefixIcon: Icon(Icons.local_shipping),
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final qty = double.tryParse(stockController.text) ?? 0.0;
                          final pCost = double.tryParse(purchaseCostController.text) ?? 0.0;
                          final tCost = double.tryParse(transportCostController.text) ?? 0.0;
                          final totalCost = pCost + tCost;
                          final perUnit = qty > 0 ? (totalCost / qty) : 0.0;

                          if (qty <= 0 || totalCost <= 0) return const SizedBox.shrink();

                          return Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Calculated Per-Unit Cost', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF))),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${perUnit.toStringAsFixed(2)} / $selectedUnit',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Total Cost', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF))),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${totalCost.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final minReorder = double.tryParse(minReorderController.text) ?? 0.0;
                          final stock = double.tryParse(stockController.text) ?? 0.0;
                          final cost = double.tryParse(purchaseCostController.text) ?? 0.0;
                          final transport = double.tryParse(transportCostController.text) ?? 0.0;

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a material name'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          try {
                            if (isEditing) {
                              final updated = RawMaterialModel(
                                id: material.id,
                                name: name,
                                unit: selectedUnit,
                                stockCount: material.stockCount, // Keep existing stock count
                                minReorderLevel: minReorder,
                              );
                              await _productionRepository.updateRawMaterial(updated);
                            } else {
                              final newItem = RawMaterialModel(
                                id: '',
                                name: name,
                                unit: selectedUnit,
                                stockCount: stock,
                                minReorderLevel: minReorder,
                              );

                              final currentUser = FirebaseAuth.instance.currentUser;
                              final String uId = currentUser?.uid ?? 'unknown';
                              final String uName = currentUser?.displayName ?? currentUser?.email ?? 'Admin';

                              await _productionRepository.addRawMaterial(
                                newItem,
                                purchaseCost: cost,
                                transportCost: transport,
                                userId: uId,
                                userName: uName,
                              );

                              // Log expense if provided
                              if (cost > 0) {
                                final expense = ExpenseModel(
                                  id: '',
                                  description: 'Raw Material Purchase: $name ($stock $selectedUnit)',
                                  amount: cost,
                                  date: DateTime.now(),
                                  type: 'Raw Materials',
                                );
                                await _expenseRepository.addExpense(expense);
                              }

                              // Log transport expense if provided
                              if (transport > 0) {
                                final transportExpense = ExpenseModel(
                                  id: '',
                                  description: 'Transport charge for buy: $name ($stock $selectedUnit)',
                                  amount: transport,
                                  date: DateTime.now(),
                                  type: 'Transport charge for material buy or delivered',
                                );
                                await _expenseRepository.addExpense(transportExpense);
                              }
                            }
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing ? 'Raw material updated successfully!' : 'Raw material added successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        child: Text(isEditing ? 'Save Changes' : 'Add Material'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showHistoryModal(RawMaterialModel material) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock History',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          material.name,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 32),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _productionRepository.watchRawMaterialAdjustments(material.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    final adjustments = snapshot.data ?? [];
                    if (adjustments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No stock history found.',
                              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: adjustments.length,
                      itemBuilder: (context, index) {
                        final log = adjustments[index];
                        final double qty = (log['adjustment'] ?? 0.0).toDouble();
                        final String action = log['action'] ?? 'Adjustment';
                        final double purchaseCost = (log['purchaseCost'] ?? 0.0).toDouble();
                        final double transportCost = (log['transportCost'] ?? 0.0).toDouble();
                        final double perUnitCost = (log['perUnitCost'] ?? 0.0).toDouble();
                        final double prevStock = (log['previousStock'] ?? 0.0).toDouble();
                        final double newStock = (log['newStock'] ?? 0.0).toDouble();
                        final String userName = log['userName'] ?? 'System';
                        
                        DateTime? logDate;
                        if (log['date'] is Timestamp) {
                          logDate = (log['date'] as Timestamp).toDate();
                        }

                        final isRestock = qty > 0;
                        final color = isRestock ? const Color(0xFF10B981) : const Color(0xFFEF4444);
                        final icon = isRestock ? Icons.add_circle_outline : Icons.remove_circle_outline;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: color.withValues(alpha: 0.1),
                                    radius: 18,
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              action,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A8A)),
                                            ),
                                            Text(
                                              '${qty > 0 ? '+' : ''}$qty ${material.unit}',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                                            ),
                                          ],
                                        ),
                                        if (logDate != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2.0),
                                            child: Text(
                                              '${logDate.day}/${logDate.month}/${logDate.year} at ${logDate.hour.toString().padLeft(2, '0')}:${logDate.minute.toString().padLeft(2, '0')}',
                                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Stock Flow: $prevStock → $newStock ${material.unit}',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                  ),
                                  Text(
                                    'By: $userName',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                              if (isRestock && (purchaseCost > 0 || transportCost > 0)) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Purchase Cost: ₹${purchaseCost.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                                          if (transportCost > 0)
                                            Text('Transport Cost: ₹${transportCost.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('Actual Per-Unit Cost', style: TextStyle(color: Color(0xFF1E40AF), fontSize: 10, fontWeight: FontWeight.w600)),
                                          Text(
                                            '₹${perUnitCost.toStringAsFixed(2)} / ${material.unit}',
                                            style: const TextStyle(color: Color(0xFF1E3A8A), fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
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

  void _showAdjustStockModal(RawMaterialModel material) {
    final amountController = TextEditingController();
    final purchaseCostController = TextEditingController();
    final transportCostController = TextEditingController();
    bool isAdding = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Adjust Stock: ${material.name}', style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Current Stock: ${material.stockCount} ${material.unit}', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAdding ? const Color(0xFF10B981) : Colors.grey.shade200,
                            foregroundColor: isAdding ? Colors.white : Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => setDialogState(() => isAdding = true),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Stock'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !isAdding ? const Color(0xFFEF4444) : Colors.grey.shade200,
                            foregroundColor: !isAdding ? Colors.white : Colors.black87,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => setDialogState(() => isAdding = false),
                          icon: const Icon(Icons.remove),
                          label: const Text('Consume'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setDialogState(() {}),
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: isAdding ? 'Quantity to Add' : 'Quantity to Subtract',
                        suffixText: material.unit,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (isAdding) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: purchaseCostController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Purchase Cost (₹)',
                          hintText: 'Optional Purchase Cost',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: transportCostController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setDialogState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Transport Cost (₹)',
                          hintText: 'Optional Transport Cost',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                          prefixIcon: Icon(Icons.local_shipping),
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          final qty = double.tryParse(amountController.text) ?? 0.0;
                          final pCost = double.tryParse(purchaseCostController.text) ?? 0.0;
                          final tCost = double.tryParse(transportCostController.text) ?? 0.0;
                          final totalCost = pCost + tCost;
                          final perUnit = qty > 0 ? (totalCost / qty) : 0.0;

                          if (qty <= 0 || totalCost <= 0) return const SizedBox.shrink();

                          return Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Per-Unit Cost:', style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF))),
                                    Text('₹${perUnit.toStringAsFixed(2)} / ${material.unit}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Cost:', style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF))),
                                    Text('₹${totalCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAdding ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final qty = double.tryParse(amountController.text) ?? 0.0;
                    final cost = double.tryParse(purchaseCostController.text) ?? 0.0;
                    final transport = double.tryParse(transportCostController.text) ?? 0.0;
                    if (qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid quantity'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    try {
                      final adjustment = isAdding ? qty : -qty;

                      final currentUser = FirebaseAuth.instance.currentUser;
                      final String uId = currentUser?.uid ?? 'unknown';
                      final String uName = currentUser?.displayName ?? currentUser?.email ?? 'Admin';

                      await _productionRepository.updateRawMaterialStock(
                        material.id, 
                        adjustment,
                        purchaseCost: cost,
                        transportCost: transport,
                        userId: uId,
                        userName: uName,
                      );
                      
                      // Log expense if purchase cost provided
                      if (isAdding && cost > 0) {
                        final expense = ExpenseModel(
                          id: '',
                          description: 'Restock: ${material.name} ($qty ${material.unit})',
                          amount: cost,
                          date: DateTime.now(),
                          type: 'Raw Materials',
                        );
                        await _expenseRepository.addExpense(expense);
                      }

                      // Log transport charge expense if provided
                      if (isAdding && transport > 0) {
                        final transportExpense = ExpenseModel(
                          id: '',
                          description: 'Transport charge for buy: ${material.name} ($qty ${material.unit})',
                          amount: transport,
                          date: DateTime.now(),
                          type: 'Transport charge for material buy or delivered',
                        );
                        await _expenseRepository.addExpense(transportExpense);
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Stock adjusted successfully!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Adjust'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(RawMaterialModel material) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Raw Material?'),
          content: Text('Are you sure you want to delete "${material.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await _productionRepository.deleteRawMaterial(material.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Material deleted successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Raw Materials Inventory', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        onPressed: () => _showMaterialModal(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Material', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<RawMaterialModel>>(
        stream: _productionRepository.watchRawMaterials(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          final materials = snapshot.data ?? [];
          if (materials.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory, size: 82, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No raw materials registered.',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add Sugar, Bottles, Caps or Flavors\nto begin tracking.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Summary Stats
          final lowStockCount = materials.where((m) => m.stockCount <= m.minReorderLevel).length;

          return Column(
            children: [
              // Top quick summary ribbon
              if (lowStockCount > 0)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '$lowStockCount raw material(s) are below the minimum re-order level!',
                          style: const TextStyle(color: Color(0xFF9F1239), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                  itemCount: materials.length,
                  itemBuilder: (context, index) {
                    final material = materials[index];
                    final isLowStock = material.stockCount <= material.minReorderLevel;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isLowStock ? const Color(0xFFFCA5A5) : Colors.grey.shade200,
                          width: isLowStock ? 1.5 : 1,
                        ),
                      ),
                      color: isLowStock ? const Color(0xFFFFF8F8) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: isLowStock 
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                      : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                  child: Icon(
                                    isLowStock ? Icons.warning_amber_rounded : Icons.water_drop,
                                    color: isLowStock ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        material.name,
                                        style: const TextStyle(
                                          fontSize: 18, 
                                          fontWeight: FontWeight.bold, 
                                          color: Color(0xFF1E3A8A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Min Reorder level: ${material.minReorderLevel} ${material.unit}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${material.stockCount} ${material.unit}',
                                      style: TextStyle(
                                        fontSize: 20, 
                                        fontWeight: FontWeight.bold, 
                                        color: isLowStock ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isLowStock 
                                            ? const Color(0xFFFEE2E2) 
                                            : const Color(0xFFD1FAE5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isLowStock ? 'Low Stock' : 'Good Stock',
                                        style: TextStyle(
                                          color: isLowStock ? const Color(0xFFEF4444) : const Color(0xFF047857),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showAdjustStockModal(material),
                                      icon: const Icon(Icons.settings_suggest, size: 16, color: Color(0xFF3B82F6)),
                                      label: const Text('Adjust', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _showHistoryModal(material),
                                      icon: const Icon(Icons.history, size: 16, color: Color(0xFF8B5CF6)),
                                      label: const Text('History', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Color(0xFF1E3A8A)),
                                      tooltip: 'Edit Details',
                                      onPressed: () => _showMaterialModal(material: material),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                                      tooltip: 'Delete Material',
                                      onPressed: () => _confirmDelete(material),
                                    ),
                                  ],
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
