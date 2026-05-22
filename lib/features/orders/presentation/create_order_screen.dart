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
import '../../customers/bloc/customer_bloc.dart';
import '../../customers/bloc/customer_event.dart';
import '../../customers/bloc/customer_state.dart';
import '../../../core/models/customer_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/route_tracker.dart';

class CreateOrderScreen extends StatefulWidget {
  final bool isRetailOrder;
  final OrderModel? existingOrder;
  const CreateOrderScreen({super.key, this.isRetailOrder = false, this.existingOrder});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final List<OrderItemModel> _cart = [];
  final double gstRate = 0.05; // 5% GST (Included in price)
  TextEditingController _shopNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _additionalNoteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  
  final UserRepository _userRepository = UserRepository();
  final OrderRepository _orderRepository = OrderRepository();
  List<UserModel> _distributors = [];
  UserModel? _selectedDistributor;
  List<UserModel> _partners = [];
  UserModel? _selectedPartnerReference;
  String _selectedReferenceType = 'Direct (Online / Call)';
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('create_order', data: {
      'isRetailOrder': widget.isRetailOrder,
      'existingOrderId': widget.existingOrder?.id,
    });
    context.read<ProductBloc>().add(LoadProducts());
    context.read<CustomerBloc>().add(LoadCustomers());
    _loadDistributors();
    
    if (widget.existingOrder != null) {
      _cart.addAll(widget.existingOrder!.items.map((item) => OrderItemModel(
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        pricePerCrate: item.pricePerCrate,
        distributorCost: item.distributorCost,
      )));
      _mobileController.text = widget.existingOrder!.customerMobile;
      _addressController.text = widget.existingOrder!.customerAddress;
      _gstController.text = widget.existingOrder!.customerGstNumber;
      _selectedDate = widget.existingOrder!.createdAt;
      _additionalNoteController.text = widget.existingOrder!.additionalNote;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Row(
        children: [
          const Text('Order Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}'),
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
            onPressed: () => _selectDate(context),
            tooltip: 'Select Date',
          ),
        ],
      ),
    );
  }

  Future<void> _loadDistributors() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && authState.user.role == 'admin') {
      setState(() => _isLoadingUsers = true);
      try {
        final dists = await _userRepository.getDistributors();
        final parts = await _userRepository.getPartners();
        setState(() {
          _distributors = dists;
          _partners = parts.where((p) => p.isActive).toList();
          
          if (widget.existingOrder != null) {
            if (widget.existingOrder!.isSupplyOrder) {
              try {
                _selectedDistributor = _distributors.firstWhere(
                  (d) => d.uid == widget.existingOrder!.targetUserId,
                );
              } catch (_) {}
            }
            if (widget.existingOrder!.orderReference != 'Direct (Online / Call)') {
              _selectedReferenceType = 'Partner Referral';
              try {
                _selectedPartnerReference = _partners.firstWhere(
                  (p) => p.name.toLowerCase().trim() == widget.existingOrder!.orderReference.toLowerCase().trim() ||
                         p.uid == widget.existingOrder!.orderReference,
                );
              } catch (_) {}
            }
          }
        });
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
    _additionalNoteController.dispose();
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

  /// Shows a dialog to edit both quantity and price together for a cart item.
  void _showEditItemDialog(int index, BuildContext dialogContext) {
    final item = _cart[index];
    final qtyController = TextEditingController(text: '${item.quantity}');
    final priceController = TextEditingController(text: item.pricePerCrate.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note, color: Color(0xFF1E3A8A)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.productName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Quantity (Crates)',
                  prefixIcon: const Icon(Icons.inventory_2_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                validator: (val) {
                  final n = int.tryParse(val?.trim() ?? '');
                  if (n == null || n < 0) return 'Enter a valid quantity';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price per Crate (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                validator: (val) {
                  final n = double.tryParse(val?.trim() ?? '');
                  if (n == null || n < 0) return 'Enter a valid price';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // Live total preview
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: qtyController,
                builder: (_, qtyVal, __) {
                  return ValueListenableBuilder<TextEditingValue>(
                    valueListenable: priceController,
                    builder: (_, priceVal, __) {
                      final qty = int.tryParse(qtyVal.text.trim()) ?? 0;
                      final price = double.tryParse(priceVal.text.trim()) ?? 0.0;
                      final lineTotal = qty * price;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$qty crates × ₹${price.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            Text('₹${lineTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A))),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          if (item.quantity > 0)
            TextButton(
              onPressed: () {
                _updateQuantity(index, 0); // remove item
                Navigator.pop(ctx);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final newQty = int.parse(qtyController.text.trim());
              final newPrice = double.parse(priceController.text.trim());
              setState(() {
                if (newQty <= 0) {
                  _cart.removeAt(index);
                } else {
                  _cart[index] = OrderItemModel(
                    productId: item.productId,
                    productName: item.productName,
                    quantity: newQty,
                    pricePerCrate: newPrice,
                    distributorCost: item.distributorCost,
                  );
                }
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
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
    String finalReference = 'Direct (Online / Call)';
    String finalReferredPartnerId = '';

    if (userRole == 'admin') {
      if (widget.isRetailOrder) {
        if (_shopNameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Shop Name')));
          return;
        }
        isSupply = false;
        targetUid = uid;
        displayPartnerName = userName; // default: admin's name
        
        if (_selectedReferenceType == 'Partner Referral') {
          if (_selectedPartnerReference == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Partner reference')));
            return;
          }
          // Credit this order to the referred partner, not the admin
          displayPartnerName = _selectedPartnerReference!.name;
          finalReference = _selectedPartnerReference!.name;
          finalReferredPartnerId = _selectedPartnerReference!.uid;
        }
      } else {
        if (_selectedDistributor == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Distributor')));
          return;
        }
        targetUid = _selectedDistributor!.uid;
        displayPartnerName = _selectedDistributor!.name;
        isSupply = true;

        if (_selectedReferenceType == 'Partner Referral') {
          if (_selectedPartnerReference == null) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Partner reference')));
            return;
          }
          // Credit this supply to the referred partner
          displayPartnerName = _selectedPartnerReference!.name;
          finalReference = _selectedPartnerReference!.name;
          finalReferredPartnerId = _selectedPartnerReference!.uid;
        }
      }
    } else {
      if (_shopNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Shop Name')));
        return;
      }
      finalReference = userName;
      if (userRole == 'partner') {
        finalReferredPartnerId = uid;
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

    String finalPaymentStatus = widget.existingOrder != null ? widget.existingOrder!.paymentStatus : 'Pending';
    double currentPaidAmount = widget.existingOrder != null ? widget.existingOrder!.paidAmount : 0.0;
    if (widget.existingOrder != null) {
      if (currentPaidAmount >= totalWithGst) {
        finalPaymentStatus = 'Paid';
      } else if (currentPaidAmount > 0.0) {
        finalPaymentStatus = 'Partial';
      } else {
        finalPaymentStatus = 'Pending';
      }
    }

    final order = OrderModel(
      id: widget.existingOrder?.id ?? '',
      createdBy: widget.existingOrder?.createdBy ?? uid,
      targetUserId: targetUid,
      partnerName: displayPartnerName,
      shopName: _shopNameController.text.trim(),
      customerMobile: _mobileController.text.trim(),
      customerAddress: _addressController.text.trim(),
      customerGstNumber: customerGst,
      invoiceNumber: widget.existingOrder?.invoiceNumber ?? invoiceNumber,
      creatorRole: widget.existingOrder?.creatorRole ?? userRole,
      isInclusiveGST: widget.existingOrder?.isInclusiveGST ?? true,
      isSupplyOrder: widget.existingOrder?.isSupplyOrder ?? isSupply,
      items: _cart,
      subtotal: subtotal,
      gstAmount: gstAmount,
      discount: widget.existingOrder?.discount ?? 0,
      finalAmount: totalWithGst,
      createdAt: _selectedDate,
      orderReference: finalReference,
      paidAmount: currentPaidAmount,
      paymentStatus: finalPaymentStatus,
      additionalNote: _additionalNoteController.text.trim(),
      referredPartnerId: finalReferredPartnerId,
    );

    if (widget.existingOrder != null) {
      context.read<OrderBloc>().add(UpdateOrder(
        order: order, 
        userId: userRole == 'admin' ? null : uid,
        userName: userRole == 'admin' ? null : userName,
      ));
    } else {
      context.read<OrderBloc>().add(CreateOrder(order: order));
    }
    
    // Sync customer bloc locally if active
    try {
      context.read<CustomerBloc>().add(LoadCustomers());
    } catch (_) {}

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(widget.existingOrder != null ? 'Order updated successfully!' : 'Order created successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showCartBottomSheet(UserModel user) {
    final outerContext = context; // capture before bottom sheet opens
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            double totalWithGst = 0;
            for (var item in _cart) {
              totalWithGst += (item.quantity * item.pricePerCrate);
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_cart.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Your cart is empty',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    ),
                  ] else ...[
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _cart.length,
                        itemBuilder: (context, index) {
                          final item = _cart[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('₹${item.pricePerCrate.toStringAsFixed(0)} × ${item.quantity} = ₹${(item.pricePerCrate * item.quantity).toStringAsFixed(0)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Edit qty + price dialog
                                IconButton(
                                  icon: const Icon(Icons.edit_note, size: 22, color: Colors.blue),
                                  onPressed: () {
                                    Navigator.pop(context); // close sheet first
                                    Future.delayed(const Duration(milliseconds: 150), () {
                                      _showEditItemDialog(index, outerContext);
                                    });
                                  },
                                  tooltip: 'Edit Qty & Price',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                  onPressed: () {
                                    _updateQuantity(index, item.quantity - 1);
                                    setModalState(() {});
                                  },
                                ),
                                // Inline tappable quantity
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Future.delayed(const Duration(milliseconds: 150), () {
                                      _showEditItemDialog(index, outerContext);
                                    });
                                  },
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 34),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFF1E3A8A), width: 1.2),
                                      borderRadius: BorderRadius.circular(6),
                                      color: const Color(0xFFF0F4FF),
                                    ),
                                    child: Text(
                                      '${item.quantity}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E3A8A),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onPressed: () {
                                    _updateQuantity(index, item.quantity + 1);
                                    setModalState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount (Incl. GST)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            '₹${totalWithGst.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _submitOrder(user.uid, user.name, user.role);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          widget.existingOrder != null 
                              ? 'Update Order' 
                              : ((user.role == 'admin' && !widget.isRetailOrder) ? 'Supply to Distributor' : 'Confirm Order'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalWithGst = 0;
    for (var item in _cart) {
      totalWithGst += (item.quantity * item.pricePerCrate);
    }

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (authContext, authState) {
        if (authState is! Authenticated) return const SizedBox();
        final user = authState.user;
        final bool isMobile = MediaQuery.of(authContext).size.width < 600;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(widget.existingOrder != null
                ? 'Edit Order Details'
                : (user.role == 'admin' && widget.isRetailOrder)
                    ? 'Create Customer Order'
                    : (user.role == 'admin' ? 'Supply Stock' : 'Create New Order')),
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
                child: (user.role == 'admin' && !widget.isRetailOrder) 
                  ? _buildAdminSelection(isMobile)
                  : _buildCustomerForm(isMobile),
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
                    // Cart (Tablet / Desktop view only)
                    if (!isMobile && _cart.isNotEmpty)
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
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.productName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '₹${item.pricePerCrate} x ${item.quantity}',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Editable quantity field + buttons (desktop panel)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit_note, size: 18, color: Colors.blue),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _showEditItemDialog(index, context),
                                                tooltip: 'Edit Qty & Price',
                                              ),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _updateQuantity(index, item.quantity - 1),
                                              ),
                                              // Inline tappable quantity
                                              GestureDetector(
                                                onTap: () => _showEditItemDialog(index, context),
                                                child: Container(
                                                  constraints: const BoxConstraints(minWidth: 36),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: const Color(0xFF1E3A8A), width: 1.2),
                                                    borderRadius: BorderRadius.circular(6),
                                                    color: const Color(0xFFF0F4FF),
                                                  ),
                                                  child: Text(
                                                    '${item.quantity}',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1E3A8A),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.green),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _updateQuantity(index, item.quantity + 1),
                                              ),
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
              if (_cart.isNotEmpty)
                isMobile
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Total (Incl. GST)',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${totalWithGst.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showCartBottomSheet(user),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                              label: Text(
                                'Review Order (${_cart.fold(0, (sum, item) => sum + item.quantity)})',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
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
                                 child: Text(
                                   widget.existingOrder != null 
                                       ? 'Update Order' 
                                       : ((user.role == 'admin' && !widget.isRetailOrder) ? 'Supply to Distributor' : 'Confirm Order'),
                                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                 ),
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

  Widget _buildCustomerForm(bool isMobile) {
    final shopField = BlocBuilder<CustomerBloc, CustomerState>(
      builder: (context, state) {
        List<CustomerModel> customers = [];
        if (state is CustomersLoaded) {
          customers = state.customers;
        }
        return Autocomplete<CustomerModel>(
          initialValue: widget.existingOrder != null 
              ? TextEditingValue(text: widget.existingOrder!.shopName) 
              : null,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<CustomerModel>.empty();
            }
            return customers.where((CustomerModel customer) {
              return customer.shopName.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          displayStringForOption: (CustomerModel option) => option.shopName,
          onSelected: (CustomerModel selection) {
            setState(() {
              _mobileController.text = selection.mobileNumber;
              _addressController.text = selection.address;
              _gstController.text = selection.gstNumber;

              if (selection.partnerId.isNotEmpty) {
                try {
                  final matchingPartner = _partners.firstWhere(
                    (p) => p.uid == selection.partnerId || p.name.toLowerCase().trim() == selection.partnerId.toLowerCase().trim(),
                  );
                  _selectedReferenceType = 'Partner Referral';
                  _selectedPartnerReference = matchingPartner;
                } catch (_) {
                  _selectedReferenceType = 'Direct (Online / Call)';
                  _selectedPartnerReference = null;
                }
              } else {
                _selectedReferenceType = 'Direct (Online / Call)';
                _selectedPartnerReference = null;
              }
            });
          },
          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<CustomerModel> onSelected, Iterable<CustomerModel> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                child: SizedBox(
                  width: 320,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final CustomerModel option = options.elementAt(index);
                      String? partnerName;
                      if (option.partnerId.isNotEmpty) {
                        try {
                          final partner = _partners.firstWhere(
                            (p) => p.uid == option.partnerId || p.name.toLowerCase().trim() == option.partnerId.toLowerCase().trim(),
                          );
                          partnerName = partner.name;
                        } catch (_) {}
                      }
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(
                          option.shopName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A), fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (option.mobileNumber.isNotEmpty)
                              Text('📞 ${option.mobileNumber}', style: const TextStyle(fontSize: 12, color: Colors.black87))
                            else
                              const Text('📞 No mobile', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            if (option.address.isNotEmpty)
                              Text('📍 ${option.address}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.black54))
                            else
                              const Text('📍 No address', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (partnerName != null) ...[
                              const SizedBox(height: 2),
                              Text('🤝 Referral: $partnerName', style: const TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                        onTap: () {
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            _shopNameController = controller;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(labelText: 'Shop Name / Customer', border: OutlineInputBorder(), isDense: true),
              onSubmitted: (String value) {
                onFieldSubmitted();
              },
            );
          },
        );
      },
    );

    final mobileField = TextField(
      controller: _mobileController,
      decoration: const InputDecoration(labelText: 'Mobile Number (Optional)', border: OutlineInputBorder(), isDense: true),
      keyboardType: TextInputType.phone,
    );

    final addressField = TextField(
      controller: _addressController,
      decoration: const InputDecoration(labelText: 'Address (Optional)', border: OutlineInputBorder(), isDense: true),
    );

    final gstField = TextField(
      controller: _gstController,
      decoration: const InputDecoration(labelText: 'GST Number (Optional)', border: OutlineInputBorder(), isDense: true),
    );

    final referenceTypeField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Order Reference / Referral:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedReferenceType,
          items: const [
            DropdownMenuItem(value: 'Direct (Online / Call)', child: Text('Direct (Online / Call)', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 'Partner Referral', child: Text('Partner Referral', style: TextStyle(fontSize: 13))),
          ],
          onChanged: (val) {
            setState(() {
              _selectedReferenceType = val ?? 'Direct (Online / Call)';
              if (_selectedReferenceType != 'Partner Referral') {
                _selectedPartnerReference = null;
              }
            });
          },
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
      ],
    );

    final partnerReferenceField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Partner Reference:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<UserModel>(
          value: _selectedPartnerReference,
          items: _partners.map((u) => DropdownMenuItem(value: u, child: Text(u.name, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (val) => setState(() => _selectedPartnerReference = val),
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
      ],
    );

    return Column(
      children: [
        if (isMobile) ...[
          shopField,
          const SizedBox(height: 12),
          mobileField,
          const SizedBox(height: 12),
          addressField,
          const SizedBox(height: 12),
          gstField,
        ] else ...[
          Row(
            children: [
              Expanded(child: shopField),
              const SizedBox(width: 12),
              Expanded(child: mobileField),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: addressField),
              const SizedBox(width: 12),
              Expanded(child: gstField),
            ],
          ),
        ],
        _buildDateSelector(),
        const SizedBox(height: 12),
        TextField(
          controller: _additionalNoteController,
          decoration: const InputDecoration(labelText: 'Additional Note (Optional)', border: OutlineInputBorder(), isDense: true),
          maxLines: 2,
        ),
        if (widget.isRetailOrder) ...[
          const SizedBox(height: 12),
          if (isMobile) ...[
            referenceTypeField,
            if (_selectedReferenceType == 'Partner Referral') ...[
              const SizedBox(height: 12),
              partnerReferenceField,
            ],
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: referenceTypeField),
                if (_selectedReferenceType == 'Partner Referral') ...[
                  const SizedBox(width: 12),
                  Expanded(child: partnerReferenceField),
                ] else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildAdminSelection(bool isMobile) {
    if (_isLoadingUsers) return const Center(child: CircularProgressIndicator());
    if (_distributors.isEmpty) return const Text('No distributors found to supply stock.');

    final distributorField = DropdownButtonFormField<UserModel>(
      value: _selectedDistributor,
      items: _distributors.map((u) => DropdownMenuItem(value: u, child: Text(u.name))).toList(),
      onChanged: (val) => setState(() => _selectedDistributor = val),
      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
    );

    final referenceTypeField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Order Reference / Referral:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedReferenceType,
          items: const [
            DropdownMenuItem(value: 'Direct (Online / Call)', child: Text('Direct (Online / Call)', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 'Partner Referral', child: Text('Partner Referral', style: TextStyle(fontSize: 13))),
          ],
          onChanged: (val) {
            setState(() {
              _selectedReferenceType = val ?? 'Direct (Online / Call)';
              if (_selectedReferenceType != 'Partner Referral') {
                _selectedPartnerReference = null;
              }
            });
          },
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
      ],
    );

    final partnerReferenceField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Partner Reference:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<UserModel>(
          value: _selectedPartnerReference,
          items: _partners.map((u) => DropdownMenuItem(value: u, child: Text(u.name, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (val) => setState(() => _selectedPartnerReference = val),
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
      ],
    );

    final addressField = TextField(
      controller: _addressController,
      decoration: const InputDecoration(labelText: 'Address (Optional)', border: OutlineInputBorder(), isDense: true),
    );

    final gstField = TextField(
      controller: _gstController,
      decoration: const InputDecoration(labelText: 'GST Number (Optional)', border: OutlineInputBorder(), isDense: true),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Distributor:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        distributorField,
        const SizedBox(height: 12),
        if (isMobile) ...[
          referenceTypeField,
          if (_selectedReferenceType == 'Partner Referral') ...[
            const SizedBox(height: 12),
            partnerReferenceField,
          ],
          const SizedBox(height: 12),
          addressField,
          const SizedBox(height: 12),
          gstField,
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: referenceTypeField),
              if (_selectedReferenceType == 'Partner Referral') ...[
                const SizedBox(width: 12),
                Expanded(child: partnerReferenceField),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: addressField),
              const SizedBox(width: 12),
              Expanded(child: gstField),
            ],
          ),
        ],
        _buildDateSelector(),
        const SizedBox(height: 12),
        TextField(
          controller: _additionalNoteController,
          decoration: const InputDecoration(labelText: 'Additional Note (Optional)', border: OutlineInputBorder(), isDense: true),
          maxLines: 2,
        ),
      ],
    );
  }
}

class CreateOrderRestoreLoader extends StatefulWidget {
  final bool isRetailOrder;
  final String? existingOrderId;
  const CreateOrderRestoreLoader({super.key, this.isRetailOrder = false, this.existingOrderId});

  @override
  State<CreateOrderRestoreLoader> createState() => _CreateOrderRestoreLoaderState();
}

class _CreateOrderRestoreLoaderState extends State<CreateOrderRestoreLoader> {
  OrderModel? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.existingOrderId != null) {
      _loadOrder();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadOrder() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(widget.existingOrderId).get();
      if (doc.exists) {
        setState(() {
          _order = OrderModel.fromFirestore(doc);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Order not found';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error ?? 'Failed to load order')),
      );
    }
    return CreateOrderScreen(
      isRetailOrder: widget.isRetailOrder,
      existingOrder: _order,
    );
  }
}

