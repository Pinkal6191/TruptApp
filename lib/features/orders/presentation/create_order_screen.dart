import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/order_item_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/user_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../products/bloc/product_bloc.dart';
import '../../products/bloc/product_event.dart';
import '../../products/bloc/product_state.dart';
import '../bloc/order_bloc.dart';
import '../bloc/order_event.dart';
import '../repository/order_repository.dart';
import '../../admin/repository/user_repository.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final List<OrderItemModel> _cart = [];
  final double gstRate = 0.05; // 5% GST (Included in price)
  final _shopNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  
  final UserRepository _userRepository = UserRepository();
  final OrderRepository _orderRepository = OrderRepository();
  List<UserModel> _distributors = [];
  UserModel? _selectedDistributor;
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    context.read<ProductBloc>().add(LoadProducts());
    _loadDistributors();
  }

  Future<void> _loadDistributors() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && authState.user.role == 'admin') {
      setState(() => _isLoadingUsers = true);
      try {
        final dists = await _userRepository.getDistributors();
        setState(() => _distributors = dists);
      } catch (e) {
        // Handle error
      } finally {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  void _addToCart(ProductModel product, UserModel user) {
    final index = _cart.indexWhere((item) => item.productId == product.id);
    
    double defaultPrice = (user.role == 'admin' && _selectedDistributor != null) 
        ? product.distributorPrice 
        : product.retailPrice;
        
    double price = user.customPrices[product.id] ?? defaultPrice;

    if (index != -1) {
      setState(() {
        final existing = _cart[index];
        _cart[index] = OrderItemModel(
          productId: existing.productId,
          productName: existing.productName,
          quantity: existing.quantity + 1,
          pricePerCrate: existing.pricePerCrate,
          distributorCost: existing.distributorCost,
        );
      });
    } else {
      setState(() {
        _cart.add(OrderItemModel(
          productId: product.id,
          productName: product.name,
          quantity: 1,
          pricePerCrate: price,
          distributorCost: product.distributorPrice, // Save original cost for accurate commission
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
          pricePerCrate: existing.pricePerCrate,
          distributorCost: existing.distributorCost,
        );
      });
    }
  }

  void _editPrice(int index) {
    final item = _cart[index];
    final controller = TextEditingController(text: item.pricePerCrate.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Price: ${item.productName}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Negotiated Price (₹)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text.trim());
              if (newPrice != null && newPrice >= 0) {
                setState(() {
                  _cart[index] = OrderItemModel(
                    productId: item.productId,
                    productName: item.productName,
                    quantity: item.quantity,
                    pricePerCrate: newPrice,
                    distributorCost: item.distributorCost,
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Update Bill Price'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder(String uid, String userName, String userRole) async {
    if (_cart.isEmpty) return;
    
    String targetUid = uid;
    String displayPartnerName = userName;
    bool isSupply = false;

    if (userRole == 'admin') {
      if (_selectedDistributor == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Distributor')));
        return;
      }
      targetUid = _selectedDistributor!.uid;
      displayPartnerName = _selectedDistributor!.name;
      isSupply = true;
    } else {
      if (_shopNameController.text.isEmpty || _mobileController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Shop Name and Mobile Number')));
        return;
      }
    }

    double totalWithGst = 0;
    for (var item in _cart) {
      totalWithGst += (item.quantity * item.pricePerCrate);
    }

    double subtotal = totalWithGst / (1 + gstRate);
    double gstAmount = totalWithGst - subtotal;

    // Show loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    String invoiceNumber = '';
    try {
      invoiceNumber = await _orderRepository.generateInvoiceNumber(isSupply, userRole);
    } catch (e) {
      invoiceNumber = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    }
    
    // Remove loading dialog
    if (context.mounted) Navigator.pop(context);

    String customerGst = _gstController.text.trim();
    if (customerGst.isEmpty) customerGst = 'URP';

    final order = OrderModel(
      id: '',
      createdBy: uid,
      targetUserId: targetUid,
      partnerName: displayPartnerName,
      shopName: _shopNameController.text.trim(),
      customerMobile: _mobileController.text.trim(),
      customerAddress: _addressController.text.trim(),
      customerGstNumber: customerGst,
      invoiceNumber: invoiceNumber,
      creatorRole: userRole,
      isInclusiveGST: true,
      isSupplyOrder: isSupply,
      items: _cart,
      subtotal: subtotal,
      gstAmount: gstAmount,
      discount: 0,
      finalAmount: totalWithGst,
      createdAt: DateTime.now(),
    );

    context.read<OrderBloc>().add(CreateOrder(order: order));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order created successfully!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalWithGst = 0;
    for (var item in _cart) {
      totalWithGst += (item.quantity * item.pricePerCrate);
    }
    double subtotal = totalWithGst / (1 + gstRate);
    double gstAmount = totalWithGst - subtotal;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) return const SizedBox();
        final user = authState.user;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(user.role == 'admin' ? 'Supply Stock' : 'Create New Order'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1E3A8A),
            elevation: 0,
          ),
          body: Column(
            children: [
              // Selection or Form
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: user.role == 'admin' 
                  ? _buildAdminSelection()
                  : _buildCustomerForm(),
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  children: [
                    // Product List
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Available Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                          ),
                          Expanded(
                            child: BlocBuilder<ProductBloc, ProductState>(
                              builder: (context, state) {
                                if (state is ProductLoading) return const Center(child: CircularProgressIndicator());
                                if (state is ProductLoaded) {
                                  return ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: state.products.length,
                                    itemBuilder: (context, index) {
                                      final p = state.products[index];
                                      double defaultPrice = (user.role == 'admin' && _selectedDistributor != null) 
                                          ? p.distributorPrice 
                                          : p.retailPrice;
                                      double displayPrice = user.customPrices[p.id] ?? defaultPrice;
                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: ListTile(
                                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('Price: ₹$displayPrice / crate\n(${p.bottlesPerCrate} bottles)'),
                                          trailing: ElevatedButton(
                                            onPressed: () => _addToCart(p, user),
                                            child: const Text('Add'),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Cart
                    if (_cart.isNotEmpty)
                      Expanded(
                        flex: 1,
                        child: Container(
                          color: Colors.white,
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: _cart.length,
                                  itemBuilder: (context, index) {
                                    final item = _cart[index];
                                    return ListTile(
                                      title: Text(item.productName),
                                      subtitle: Text('₹${item.pricePerCrate} x ${item.quantity}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                            onPressed: () => _editPrice(index),
                                            tooltip: 'Negotiate Price',
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(icon: const Icon(Icons.remove), onPressed: () => _updateQuantity(index, item.quantity - 1)),
                                          Text('${item.quantity}'),
                                          IconButton(icon: const Icon(Icons.add), onPressed: () => _updateQuantity(index, item.quantity + 1)),
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
              if (_cart.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total (Inclusive of GST)'),
                          Text('₹${totalWithGst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => _submitOrder(user.uid, user.name, user.role),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                          child: Text(user.role == 'admin' ? 'Supply to Distributor' : 'Confirm Order', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _shopNameController,
                decoration: const InputDecoration(labelText: 'Shop Name / Customer', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address (Optional)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _gstController,
                decoration: const InputDecoration(labelText: 'GST Number (Optional)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminSelection() {
    if (_isLoadingUsers) return const Center(child: CircularProgressIndicator());
    if (_distributors.isEmpty) return const Text('No distributors found to supply stock.');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Distributor:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<UserModel>(
          value: _selectedDistributor,
          items: _distributors.map((u) => DropdownMenuItem(value: u, child: Text(u.name))).toList(),
          onChanged: (val) => setState(() => _selectedDistributor = val),
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address (Optional)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _gstController,
                decoration: const InputDecoration(labelText: 'GST Number (Optional)', border: OutlineInputBorder(), isDense: true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
