import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/order_item_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/product_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../products/bloc/product_bloc.dart';
import '../../products/bloc/product_event.dart';
import '../../products/bloc/product_state.dart';
import '../bloc/order_bloc.dart';
import '../bloc/order_event.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final List<OrderItemModel> _cart = [];
  final double gstRate = 0.18; // 18% GST

  @override
  void initState() {
    super.initState();
    context.read<ProductBloc>().add(LoadProducts());
  }

  void _addToCart(ProductModel product, String userRole) {
    // Check if already in cart
    final index = _cart.indexWhere((item) => item.productId == product.id);
    if (index != -1) {
      setState(() {
        final existing = _cart[index];
        _cart[index] = OrderItemModel(
          productId: existing.productId,
          productName: existing.productName,
          quantity: existing.quantity + 1,
          unitPrice: existing.unitPrice,
          margin: existing.margin,
        );
      });
    } else {
      setState(() {
        _cart.add(OrderItemModel(
          productId: product.id,
          productName: product.name,
          quantity: 1,
          unitPrice: product.defaultPrice,
        ));
      });
    }
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      setState(() {
        _cart.removeAt(index);
      });
    } else {
      setState(() {
        final existing = _cart[index];
        _cart[index] = OrderItemModel(
          productId: existing.productId,
          productName: existing.productName,
          quantity: newQuantity,
          unitPrice: existing.unitPrice,
          margin: existing.margin,
        );
      });
    }
  }

  void _updatePrice(int index, double newPrice) {
    setState(() {
      final existing = _cart[index];
      _cart[index] = OrderItemModel(
        productId: existing.productId,
        productName: existing.productName,
        quantity: existing.quantity,
        unitPrice: newPrice,
        margin: existing.margin,
      );
    });
  }

  void _submitOrder(String uid, String name) {
    if (_cart.isEmpty) return;

    double subtotal = 0;
    for (var item in _cart) {
      subtotal += (item.quantity * item.unitPrice);
    }
    double gstAmount = subtotal * gstRate;
    double finalAmount = subtotal + gstAmount;

    final order = OrderModel(
      id: '', // Auto-generated
      createdBy: uid,
      partnerName: name,
      items: _cart,
      subtotal: subtotal,
      gstAmount: gstAmount,
      discount: 0,
      finalAmount: finalAmount,
      createdAt: DateTime.now(),
    );

    context.read<OrderBloc>().add(CreateOrder(order: order));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order created successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double subtotal = 0;
    for (var item in _cart) {
      subtotal += (item.quantity * item.unitPrice);
    }
    double gstAmount = subtotal * gstRate;
    double finalAmount = subtotal + gstAmount;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) return const SizedBox();
        final user = authState.user;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Create New Order'),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E3A8A),
          ),
          body: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product List Section
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Available Products',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: BlocBuilder<ProductBloc, ProductState>(
                                builder: (context, state) {
                                  if (state is ProductLoading) {
                                    return const Center(child: CircularProgressIndicator());
                                  } else if (state is ProductLoaded) {
                                    return ListView.builder(
                                      itemCount: state.products.length,
                                      itemBuilder: (context, index) {
                                        final product = state.products[index];
                                        return Card(
                                          elevation: 2,
                                          shadowColor: Colors.black12,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          margin: const EdgeInsets.only(bottom: 12),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            title: Text(
                                              product.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Text('Base Price: ₹${product.defaultPrice}'),
                                            trailing: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF3B82F6),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: () => _addToCart(product, user.role),
                                              child: const Text('Add'),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }
                                  return const Center(child: Text('Failed to load products.'));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Cart Section (Visible if not empty)
                    if (_cart.isNotEmpty)
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(left: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Current Order',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _cart.length,
                                  itemBuilder: (context, index) {
                                    final item = _cart[index];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item.productName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              Text(
                                                '₹${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              // Quantity Controls
                                              Container(
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.grey.shade300),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.remove, size: 16),
                                                      onPressed: () => _updateQuantity(index, item.quantity - 1),
                                                    ),
                                                    Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                    IconButton(
                                                      icon: const Icon(Icons.add, size: 16),
                                                      onPressed: () => _updateQuantity(index, item.quantity + 1),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              // Price Editable for Distributors
                                              if (user.role == 'distributor') ...[
                                                const Text('₹'),
                                                SizedBox(
                                                  width: 60,
                                                  child: TextFormField(
                                                    initialValue: item.unitPrice.toString(),
                                                    keyboardType: TextInputType.number,
                                                    decoration: const InputDecoration(
                                                      isDense: true,
                                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                      border: OutlineInputBorder(),
                                                    ),
                                                    onChanged: (val) {
                                                      if (val.isNotEmpty) {
                                                        _updatePrice(index, double.parse(val));
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ] else ...[
                                                Text('₹${item.unitPrice} / unit', style: TextStyle(color: Colors.grey.shade600)),
                                              ]
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Bottom Summary Bar
              if (_cart.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal', style: TextStyle(color: Colors.grey)),
                            Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('GST (18%)', style: TextStyle(color: Colors.grey)),
                            Text('₹${gstAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('₹${finalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _submitOrder(user.uid, user.name),
                            child: const Text('Confirm Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
