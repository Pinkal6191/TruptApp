import 'package:flutter/material.dart';
import '../../../core/models/raw_material_model.dart';
import '../../../core/utils/route_tracker.dart';
import '../repository/production_repository.dart';

class RawMaterialsScreen extends StatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  State<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends State<RawMaterialsScreen> {
  final ProductionRepository _productionRepository = ProductionRepository();

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
                      TextField(
                        controller: stockController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Initial Stock Count',
                          hintText: 'e.g. 100.0',
                          border: OutlineInputBorder(),
                        ),
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
                              await _productionRepository.addRawMaterial(newItem);
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

  void _showAdjustStockModal(RawMaterialModel material) {
    final amountController = TextEditingController();
    bool isAdding = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Adjust Stock: ${material.name}', style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
              content: Column(
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
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: isAdding ? 'Quantity to Add' : 'Quantity to Subtract',
                      suffixText: material.unit,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
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
                    if (qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid quantity'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    try {
                      final adjustment = isAdding ? qty : -qty;
                      await _productionRepository.updateRawMaterialStock(material.id, adjustment);
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
                                TextButton.icon(
                                  onPressed: () => _showAdjustStockModal(material),
                                  icon: const Icon(Icons.settings_suggest, size: 18, color: Color(0xFF3B82F6)),
                                  label: const Text('Adjust Stock', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
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
