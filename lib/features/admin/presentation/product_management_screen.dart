import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../products/bloc/product_bloc.dart';
import '../../products/bloc/product_event.dart' as events;
import '../../products/bloc/product_state.dart';
import '../../../core/models/product_model.dart';
import '../../inventory/repository/production_repository.dart';
import '../../../core/models/raw_material_model.dart';
import '../../../core/utils/route_tracker.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('product_management');
  }

  void _showProductForm(BuildContext context, {ProductModel? product}) {
    final nameController = TextEditingController(text: product?.name);
    final bottlesController = TextEditingController(text: product?.bottlesPerCrate.toString());
    final retailController = TextEditingController(text: product?.retailPrice.toString());
    final distributorController = TextEditingController(text: product?.distributorPrice.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product == null ? 'Add New Product' : 'Edit Product',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Product Name (e.g. 200ml)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bottlesController,
                decoration: const InputDecoration(labelText: 'Bottles per Crate', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: retailController,
                decoration: const InputDecoration(labelText: 'Retail Price (per Crate)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: distributorController,
                decoration: const InputDecoration(labelText: 'Distributor Price (per Crate)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final newProduct = ProductModel(
                      id: product?.id ?? '',
                      name: nameController.text.trim(),
                      bottlesPerCrate: int.tryParse(bottlesController.text) ?? 0,
                      retailPrice: double.tryParse(retailController.text) ?? 0.0,
                      distributorPrice: double.tryParse(distributorController.text) ?? 0.0,
                      recipe: product?.recipe ?? const [], // Keep recipe intact
                    );

                    if (product == null) {
                      context.read<ProductBloc>().add(events.AddProduct(newProduct));
                    } else {
                      context.read<ProductBloc>().add(events.UpdateProduct(newProduct));
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                  child: Text(product == null ? 'Add Product' : 'Update Product'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecipeDialog(BuildContext context, ProductModel product) {
    final ProductionRepository productionRepository = ProductionRepository();
    List<Map<String, dynamic>> tempRecipe = List<Map<String, dynamic>>.from(product.recipe);
    RawMaterialModel? selectedMaterial;
    final qtyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return StreamBuilder<List<RawMaterialModel>>(
              stream: productionRepository.watchRawMaterials(),
              builder: (context, snapshot) {
                final materials = snapshot.data ?? [];
                
                // Exclude already added materials
                final availableMaterials = materials.where((m) {
                  return !tempRecipe.any((r) => r['materialId'] == m.id);
                }).toList();

                if (selectedMaterial != null && !availableMaterials.contains(selectedMaterial)) {
                  selectedMaterial = null;
                }
                if (selectedMaterial == null && availableMaterials.isNotEmpty) {
                  selectedMaterial = availableMaterials.first;
                }

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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Product Recipe Formula',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                  ),
                                  Text(
                                    'Product: ${product.name}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            )
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Current Recipe (Quantity per Crate of finished product)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        if (tempRecipe.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber.shade800),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No ingredients specified. Add raw materials below to automatically deduct stock on production.',
                                    style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: tempRecipe.length,
                            separatorBuilder: (context, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final item = tempRecipe[index];
                              final matId = item['materialId'];
                              final qty = (item['quantityPerCrate'] ?? 0.0).toDouble();
                              
                              // Find material name and unit
                              final mat = materials.firstWhere(
                                (m) => m.id == matId,
                                orElse: () => RawMaterialModel(id: matId, name: 'Unknown', unit: 'pcs', stockCount: 0, minReorderLevel: 0),
                              );

                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFE0F2FE),
                                  child: const Icon(Icons.science, color: Color(0xFF3B82F6), size: 18),
                                ),
                                title: Text(mat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('Consumes: $qty ${mat.unit} per crate'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () {
                                    setModalState(() {
                                      tempRecipe.removeAt(index);
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        const Divider(height: 32),
                        const Text(
                          'Add Raw Material to Recipe',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(height: 12),
                        if (availableMaterials.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('No additional raw materials available.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<RawMaterialModel>(
                                  value: selectedMaterial,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Material',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: availableMaterials.map((m) {
                                    return DropdownMenuItem(value: m, child: Text('${m.name} (${m.unit})'));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() => selectedMaterial = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: qtyController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Qty/Crate',
                                    suffixText: selectedMaterial?.unit ?? '',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () {
                                final qty = double.tryParse(qtyController.text) ?? 0.0;
                                if (qty <= 0.0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid quantity'), backgroundColor: Colors.red),
                                  );
                                  return;
                                }
                                if (selectedMaterial == null) return;

                                setModalState(() {
                                  tempRecipe.add({
                                    'materialId': selectedMaterial!.id,
                                    'quantityPerCrate': qty,
                                  });
                                  qtyController.clear();
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Material to Formula', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              final updatedProduct = ProductModel(
                                id: product.id,
                                name: product.name,
                                bottlesPerCrate: product.bottlesPerCrate,
                                retailPrice: product.retailPrice,
                                distributorPrice: product.distributorPrice,
                                recipe: tempRecipe,
                              );

                              context.read<ProductBloc>().add(events.UpdateProduct(updatedProduct));
                              Navigator.pop(context);
                            },
                            child: const Text('Save Recipe Formula', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProductionRepository productionRepository = ProductionRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Manage Products', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: BlocConsumer<ProductBloc, ProductState>(
        listener: (context, state) {
          if (state is ProductOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
          } else if (state is ProductError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        builder: (context, state) {
          if (state is ProductLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ProductLoaded) {
            final products = state.products;
            if (products.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No products found', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Click + to create your first product', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            return StreamBuilder<List<RawMaterialModel>>(
              stream: productionRepository.watchRawMaterials(),
              builder: (context, matSnapshot) {
                final materials = matSnapshot.data ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];

                    // Generate a nice recipe summary string for this product card
                    String recipeSummary = 'Not configured';
                    if (product.recipe.isNotEmpty && materials.isNotEmpty) {
                      final items = product.recipe.map((r) {
                        final matId = r['materialId'];
                        final qty = r['quantityPerCrate'] ?? 0.0;
                        final mat = materials.firstWhere(
                          (m) => m.id == matId,
                          orElse: () => RawMaterialModel(id: matId, name: 'Unknown', unit: 'pcs', stockCount: 0, minReorderLevel: 0),
                        );
                        return '${mat.name}: $qty${mat.unit}';
                      }).toList();
                      recipeSummary = items.join(' • ');
                    }

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
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
                                    product.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3A8A)),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${product.bottlesPerCrate} bottles / crate',
                                    style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: Text('Retail: ₹${product.retailPrice}', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: Text('Distributor: ₹${product.distributorPrice}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            // Recipe section on the card
                            Row(
                              children: [
                                const Icon(Icons.science_outlined, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                const Text('Recipe: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54, fontSize: 12)),
                                Expanded(
                                  child: Text(
                                    recipeSummary,
                                    style: TextStyle(
                                      color: product.recipe.isEmpty ? Colors.amber.shade700 : Colors.black87,
                                      fontSize: 12,
                                      fontStyle: product.recipe.isEmpty ? FontStyle.italic : FontStyle.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            // Action buttons row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _showRecipeDialog(context, product),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: product.recipe.isEmpty ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                                    foregroundColor: product.recipe.isEmpty ? const Color(0xFFC2410C) : const Color(0xFF15803D),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    side: BorderSide(
                                      color: product.recipe.isEmpty ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                                    ),
                                  ),
                                  icon: const Icon(Icons.science, size: 16),
                                  label: const Text('Configure Recipe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Color(0xFF1E3A8A)),
                                      tooltip: 'Edit details',
                                      onPressed: () => _showProductForm(context, product: product),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                                      tooltip: 'Delete product',
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Product'),
                                            content: Text('Are you sure you want to delete ${product.name}?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                                              ElevatedButton(
                                                onPressed: () {
                                                  context.read<ProductBloc>().add(events.DeleteProduct(product.id));
                                                  Navigator.pop(context);
                                                },
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
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
                );
              },
            );
          }
          return const Center(child: Text('Something went wrong.'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductForm(context),
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
