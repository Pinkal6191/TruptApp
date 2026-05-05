import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../products/bloc/product_bloc.dart';
import '../../products/bloc/product_event.dart' as events;
import '../../products/bloc/product_state.dart';
import '../../../core/models/product_model.dart';

class ProductManagementScreen extends StatelessWidget {
  const ProductManagementScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Manage Products'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: BlocConsumer<ProductBloc, ProductState>(
        listener: (context, state) {
          if (state is ProductOperationSuccess) {
            final successState = state as ProductOperationSuccess;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successState.message), backgroundColor: Colors.green));
          } else if (state is ProductError) {
            final errorState = state as ProductError;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorState.message), backgroundColor: Colors.red));
          }
        },
        builder: (context, state) {
          if (state is ProductLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ProductLoaded) {
            final products = (state as ProductLoaded).products;
            if (products.isEmpty) {
              return const Center(child: Text('No products. Click + to add.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${product.bottlesPerCrate} bottles / crate'),
                        const SizedBox(height: 4),
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
                              child: Text('Dist: ₹${product.distributorPrice}', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showProductForm(context, product: product),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Product'),
                                content: Text('Are you sure you want to delete ${product.name}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () {
                                      context.read<ProductBloc>().add(events.DeleteProduct(product.id));
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
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
