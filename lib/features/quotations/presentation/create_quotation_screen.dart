import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/quotation_model.dart';
import '../../../core/models/product_model.dart';
import '../../products/bloc/product_bloc.dart';
import '../../products/bloc/product_state.dart';
import '../services/quotation_pdf_service.dart';

class CreateQuotationScreen extends StatefulWidget {
  final QuotationModel? existingQuotation;
  const CreateQuotationScreen({super.key, this.existingQuotation});

  @override
  State<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends State<CreateQuotationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _oneTimeChargeController = TextEditingController();
  final _termsController = TextEditingController();

  DateTime _createdAt = DateTime.now();
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  String _quotationType = 'Regular Bottle';
  bool _withGst = true;

  final List<QuotationItemModel> _cart = [];

  // Item form inputs
  final _itemNameController = TextEditingController();
  final _itemQtyController = TextEditingController();
  final _itemPriceController = TextEditingController();
  String _selectedUnit = 'Crates';

  List<ProductModel> _availableProducts = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableProducts();

    if (widget.existingQuotation != null) {
      final q = widget.existingQuotation!;
      _shopNameController.text = q.shopName;
      _contactPersonController.text = q.contactPerson;
      _mobileController.text = q.customerMobile;
      _addressController.text = q.customerAddress;
      _oneTimeChargeController.text = q.oneTimeCharge > 0 ? q.oneTimeCharge.toString() : '';
      _termsController.text = q.termsConditions;
      _createdAt = q.createdAt;
      _validUntil = q.validUntil;
      _quotationType = q.quotationType;
      _withGst = q.withGst;
      _cart.addAll(q.items);
    } else {
      _updateDefaultTerms();
    }
  }

  void _loadAvailableProducts() {
    final state = context.read<ProductBloc>().state;
    if (state is ProductLoaded) {
      setState(() {
        _availableProducts = state.products;
      });
    }
  }

  void _updateDefaultTerms() {
    if (_quotationType == 'Custom Branding') {
      _termsController.text = 
          '1. 50% advance payment required upon order confirmation.\n'
          '2. Delivery: 7-10 working days from artwork confirmation.\n'
          '3. Customized label printing charges are applicable for first-time orders.\n'
          '4. Quotation is valid for 30 days.\n'
          '5. Transport and freight charges are extra.';
    } else if (_quotationType == 'Distributor Supply') {
      _termsController.text = 
          '1. Security deposit and signed contract required for distributor status.\n'
          '2. Supply schedules will follow standard weekly dispatch rotations.\n'
          '3. Payments must be processed as per standard billing cycles.\n'
          '4. Quotation is valid for 30 days.\n'
          '5. Transport and freight charges are extra.';
    } else {
      _termsController.text = 
          '1. Standard payment terms upon receipt of order.\n'
          '2. Standard deliveries will complete in 2-3 business days.\n'
          '3. Crates remain the property of Trupt Enterprise and must be returned.\n'
          '4. Quotation is valid for 30 days.\n'
          '5. Transport and freight charges are extra.';
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _contactPersonController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _oneTimeChargeController.dispose();
    _termsController.dispose();
    _itemNameController.dispose();
    _itemQtyController.dispose();
    _itemPriceController.dispose();
    super.dispose();
  }

  double get _subtotal {
    double total = 0.0;
    for (var item in _cart) {
      total += item.quantity * item.pricePerUnit;
    }
    final oneTime = double.tryParse(_oneTimeChargeController.text.trim()) ?? 0.0;
    total += oneTime;
    if (_withGst) {
      return total / 1.05; // 5% inclusive GST
    }
    return total;
  }

  double get _gstAmount {
    double total = 0.0;
    for (var item in _cart) {
      total += item.quantity * item.pricePerUnit;
    }
    final oneTime = double.tryParse(_oneTimeChargeController.text.trim()) ?? 0.0;
    total += oneTime;
    if (_withGst) {
      return total - _subtotal;
    }
    return 0.0;
  }

  double get _finalAmount {
    double total = 0.0;
    for (var item in _cart) {
      total += item.quantity * item.pricePerUnit;
    }
    final oneTime = double.tryParse(_oneTimeChargeController.text.trim()) ?? 0.0;
    total += oneTime;
    return total;
  }

  Future<void> _selectDate(BuildContext context, bool isCreatedDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isCreatedDate ? _createdAt : _validUntil,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isCreatedDate) {
          _createdAt = picked;
          // Shift validUntil automatically to +30 days
          _validUntil = picked.add(const Duration(days: 30));
        } else {
          _validUntil = picked;
        }
      });
    }
  }

  void _addItemToCart() {
    final name = _itemNameController.text.trim();
    final qty = int.tryParse(_itemQtyController.text.trim()) ?? 0;
    final price = double.tryParse(_itemPriceController.text.trim()) ?? 0.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter item name / description')),
      );
      return;
    }
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than zero')),
      );
      return;
    }
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price per unit must be greater than zero')),
      );
      return;
    }

    setState(() {
      _cart.add(QuotationItemModel(
        productName: name,
        quantity: qty,
        pricePerUnit: price,
        unitType: _selectedUnit,
      ));
      _itemNameController.clear();
      _itemQtyController.clear();
      _itemPriceController.clear();
    });
  }

  Future<void> _saveAndGenerate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item to the quotation')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final docId = widget.existingQuotation?.id ?? FirebaseFirestore.instance.collection('quotations').doc().id;
      
      // Auto-generate a beautiful quotation number if new
      String qNumber = widget.existingQuotation?.quotationNumber ?? '';
      if (qNumber.isEmpty) {
        final year = DateFormat('yy').format(_createdAt);
        final month = DateFormat('MM').format(_createdAt);
        final countSnapshot = await FirebaseFirestore.instance.collection('quotations').get();
        final count = countSnapshot.docs.length + 1;
        final formattedCount = count.toString().padLeft(4, '0');
        qNumber = 'TE/Q/$year-$month/$formattedCount';
      }

      final oneTimeVal = double.tryParse(_oneTimeChargeController.text.trim()) ?? 0.0;

      final quotation = QuotationModel(
        id: docId,
        quotationNumber: qNumber,
        shopName: _shopNameController.text.trim(),
        contactPerson: _contactPersonController.text.trim(),
        customerMobile: _mobileController.text.trim(),
        customerAddress: _addressController.text.trim(),
        createdAt: _createdAt,
        validUntil: _validUntil,
        quotationType: _quotationType,
        items: _cart,
        subtotal: _subtotal,
        gstAmount: _gstAmount,
        oneTimeCharge: oneTimeVal,
        finalAmount: _finalAmount,
        withGst: _withGst,
        termsConditions: _termsController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('quotations')
          .doc(docId)
          .set(quotation.toMap());

      if (mounted) {
        Navigator.pop(context); // Dismiss loading
        // Pop screen and return quotation to view/generate immediately
        Navigator.pop(context, true);
        
        // Generate PDF
        QuotationPdfService.generateAndShareQuotation(quotation);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving quotation: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.existingQuotation != null ? 'Edit Quotation' : 'Create Quotation'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Quotation Info Card
              _sectionTitle('Client & Quotation Details'),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _quotationType,
                        decoration: const InputDecoration(
                          labelText: 'Quotation Type',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Regular Bottle', 'Custom Branding', 'Distributor Supply']
                            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _quotationType = val;
                              _updateDefaultTerms();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _shopNameController,
                        decoration: const InputDecoration(
                          labelText: 'Company / Shop Name *',
                          hintText: 'e.g. Grand Taj Hotel, Boriavi',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter client name' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _contactPersonController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Person Name',
                          hintText: 'e.g. Mr. Rajesh Patel',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Contact Mobile *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter mobile number' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Client Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _oneTimeChargeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: '1-Time Custom Bottle / Mold Fixed Charge (₹)',
                          hintText: 'Optional setup costs e.g. 5000',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monetization_on_outlined),
                        ),
                        onChanged: (val) {
                          setState(() {}); // Recalculate totals dynamically!
                        },
                      ),
                      const SizedBox(height: 16),
                      // Date selectors
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Color(0xFF1E3A8A)),
                              ),
                              icon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF1E3A8A)),
                              label: Text('Date: ${DateFormat('dd MMM yy').format(_createdAt)}', style: const TextStyle(color: Color(0xFF1E3A8A))),
                              onPressed: () => _selectDate(context, true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              icon: const Icon(Icons.event_busy, size: 18, color: Colors.redAccent),
                              label: Text('Valid: ${DateFormat('dd MMM yy').format(_validUntil)}', style: const TextStyle(color: Colors.redAccent)),
                              onPressed: () => _selectDate(context, false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Add Item Card
              _sectionTitle('Add Quotation Items'),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: const Color(0xFFEFF6FF),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Autocomplete<ProductModel>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<ProductModel>.empty();
                              }
                              return _availableProducts.where((product) {
                                return product.name.toLowerCase().contains(textEditingValue.text.toLowerCase());
                              });
                            },
                            displayStringForOption: (option) => option.name,
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              // Sync text field to controller
                              _itemNameController.text = textEditingController.text;
                              textEditingController.addListener(() {
                                _itemNameController.text = textEditingController.text;
                              });

                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Item Name / Custom Brand Item *',
                                  hintText: 'Select or type e.g. Trupt Premium 500ml',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.water_drop),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              );
                            },
                            onSelected: (option) {
                              setState(() {
                                _itemNameController.text = option.name;
                                _itemPriceController.text = _quotationType == 'Distributor Supply' 
                                    ? option.distributorPrice.toString() 
                                    : option.retailPrice.toString();
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _itemQtyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: _selectedUnit,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: ['Crates', 'Bottles', 'Boxes', 'Units']
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedUnit = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: _itemPriceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Price per Unit (₹)',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add to Estimate', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _addItemToCart,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Cart / Items Added List
              if (_cart.isNotEmpty) ...[
                _sectionTitle('Quoted Estimate Items'),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cart.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return ListTile(
                        title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Qty: ${item.quantity} ${item.unitType} x ₹${item.pricePerUnit.toStringAsFixed(2)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹${(item.quantity * item.pricePerUnit).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _cart.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 4. Quotation Terms
              _sectionTitle('Quotation Terms & Conditions'),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _termsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Terms & Conditions (Editable)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 5. Total Calculations Card
              Card(
                color: const Color(0xFF1E3A8A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated GST configuration', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          Switch(
                            value: _withGst,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              setState(() {
                                _withGst = val;
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white30, height: 16),
                      if (_withGst) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Taxable Value', style: TextStyle(color: Colors.white70)),
                            Text('₹${_subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('SGST (2.5%)', style: TextStyle(color: Colors.white70)),
                            Text('₹${(_gstAmount / 2).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('CGST (2.5%)', style: TextStyle(color: Colors.white70)),
                            Text('₹${(_gstAmount / 2).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                        const Divider(color: Colors.white30, height: 24),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Final Quoted Price',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            '₹${_finalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 6. Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(
                    widget.existingQuotation != null ? 'Update & Download PDF' : 'Save & Download PDF',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _saveAndGenerate,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E3A8A),
        ),
      ),
    );
  }
}
