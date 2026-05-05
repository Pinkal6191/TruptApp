import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../products/bloc/product_bloc.dart';
import '../../products/bloc/product_state.dart';
import '../../admin/repository/user_repository.dart';
import '../../../core/models/user_model.dart';

class CustomPriceScreen extends StatefulWidget {
  const CustomPriceScreen({super.key});

  @override
  State<CustomPriceScreen> createState() => _CustomPriceScreenState();
}

class _CustomPriceScreenState extends State<CustomPriceScreen> {
  final UserRepository _userRepository = UserRepository();
  late Map<String, double> _localCustomPrices;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _localCustomPrices = Map.from(authState.user.customPrices);
    } else {
      _localCustomPrices = {};
    }
  }

  Future<void> _savePrices(UserModel user) async {
    setState(() => _isSaving = true);
    try {
      await _userRepository.updateCustomPrices(user.uid, _localCustomPrices);
      final updatedUser = UserModel(
        uid: user.uid,
        name: user.name,
        mobile: user.mobile,
        role: user.role,
        gstNumber: user.gstNumber,
        isApproved: user.isApproved,
        customPrices: _localCustomPrices,
      );
      if (mounted) {
        context.read<AuthBloc>().add(UpdateUserModel(user: updatedUser));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom prices saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _editPriceDialog(BuildContext context, String productId, String productName, double currentPrice) {
    final controller = TextEditingController(text: currentPrice.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Price: $productName'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Your Selling Price (₹)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text.trim());
              if (newPrice != null && newPrice >= 0) {
                setState(() {
                  _localCustomPrices[productId] = newPrice;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Set Price'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) return const Scaffold(body: Center(child: Text('Not authenticated')));
        final user = authState.user;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('My Custom Prices'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E3A8A),
            elevation: 0,
            actions: [
              if (_isSaving)
                const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: CircularProgressIndicator()))
              else
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () => _savePrices(user),
                  tooltip: 'Save Prices',
                )
            ],
          ),
          body: BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              if (state is ProductLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is ProductLoaded) {
                final products = state.products;
                if (products.isEmpty) {
                  return const Center(child: Text('No products available.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final defaultPrice = user.role == 'distributor' ? p.distributorPrice : p.retailPrice;
                    final displayPrice = _localCustomPrices[p.id] ?? defaultPrice;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Base System Price: ₹$defaultPrice'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹$displayPrice',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E3A8A)),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.grey),
                              onPressed: () => _editPriceDialog(context, p.id, p.name, displayPrice),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
              return const Center(child: Text('Failed to load products.'));
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isSaving ? null : () => _savePrices(user),
            label: const Text('Save Changes'),
            icon: const Icon(Icons.save),
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }
}
