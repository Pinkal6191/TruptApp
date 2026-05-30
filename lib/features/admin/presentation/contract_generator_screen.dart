import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../customers/bloc/customer_bloc.dart';
import '../../customers/bloc/customer_event.dart';
import '../../customers/bloc/customer_state.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/utils/route_tracker.dart';
import 'pdf_contract_service.dart';

import '../../../core/models/contract_model.dart';
import '../../contracts/bloc/contract_bloc.dart';
import '../../contracts/bloc/contract_event.dart';

class ContractGeneratorScreen extends StatefulWidget {
  final ContractModel? contractToEdit;
  const ContractGeneratorScreen({super.key, this.contractToEdit});

  @override
  State<ContractGeneratorScreen> createState() => _ContractGeneratorScreenState();
}

class _ContractGeneratorScreenState extends State<ContractGeneratorScreen> {
  String? _selectedCustomerId;
  final TextEditingController _oneTimeFeesController = TextEditingController(text: '5000');
  final TextEditingController _price200mlController = TextEditingController(text: '70');
  final TextEditingController _price500mlController = TextEditingController(text: '80');
  final TextEditingController _price1LController = TextEditingController(text: '90');
  final TextEditingController _moq200mlController = TextEditingController(text: '100');
  final TextEditingController _moq500mlController = TextEditingController(text: '100');
  final TextEditingController _moq1LController = TextEditingController(text: '100');
  final TextEditingController _contractDurationController = TextEditingController(text: '12 Months');

  bool _include200ml = true;
  bool _include500ml = true;
  bool _include1L = true;

  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('contract_generator');
    final customerState = context.read<CustomerBloc>().state;
    if (customerState is CustomerInitial || customerState is CustomerError || (customerState is CustomersLoaded && customerState.customers.isEmpty)) {
      context.read<CustomerBloc>().add(LoadCustomers());
    }

    if (widget.contractToEdit != null) {
      final c = widget.contractToEdit!;
      _selectedCustomerId = c.customerId;
      _oneTimeFeesController.text = c.oneTimeFees.toString();
      _contractDurationController.text = c.duration;

      _include200ml = c.price200ml != null;
      if (c.price200ml != null) _price200mlController.text = c.price200ml.toString();
      if (c.moq200ml != null) _moq200mlController.text = c.moq200ml.toString();

      _include500ml = c.price500ml != null;
      if (c.price500ml != null) _price500mlController.text = c.price500ml.toString();
      if (c.moq500ml != null) _moq500mlController.text = c.moq500ml.toString();

      _include1L = c.price1L != null;
      if (c.price1L != null) _price1LController.text = c.price1L.toString();
      if (c.moq1L != null) _moq1LController.text = c.moq1L.toString();
    }
  }

  @override
  void dispose() {
    _oneTimeFeesController.dispose();
    _price200mlController.dispose();
    _price500mlController.dispose();
    _price1LController.dispose();
    _moq200mlController.dispose();
    _moq500mlController.dispose();
    _moq1LController.dispose();
    _contractDurationController.dispose();
    super.dispose();
  }

  Future<void> _generatePdf(List<CustomerModel> customers) async {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a custom label customer first.')),
      );
      return;
    }
    final selectedCustomer = customers.firstWhere((c) => c.id == _selectedCustomerId);

    setState(() => _isGenerating = true);
    try {
      final fees = double.tryParse(_oneTimeFeesController.text) ?? 0.0;
      final p200 = double.tryParse(_price200mlController.text) ?? 0.0;
      final p500 = double.tryParse(_price500mlController.text) ?? 0.0;
      final p1 = double.tryParse(_price1LController.text) ?? 0.0;
      final m200 = int.tryParse(_moq200mlController.text) ?? 100;
      final m500 = int.tryParse(_moq500mlController.text) ?? 100;
      final m1 = int.tryParse(_moq1LController.text) ?? 100;

      final contract = ContractModel(
        id: widget.contractToEdit?.id ?? '',
        customerId: selectedCustomer.id,
        customerName: selectedCustomer.shopName,
        customerAddress: selectedCustomer.address,
        customerContact: selectedCustomer.mobileNumber,
        createdAt: widget.contractToEdit?.createdAt ?? DateTime.now(),
        oneTimeFees: fees,
        price200ml: _include200ml ? p200 : null,
        moq200ml: _include200ml ? m200 : null,
        price500ml: _include500ml ? p500 : null,
        moq500ml: _include500ml ? m500 : null,
        price1L: _include1L ? p1 : null,
        moq1L: _include1L ? m1 : null,
        duration: _contractDurationController.text,
      );

      if (widget.contractToEdit == null) {
        context.read<ContractBloc>().add(AddContract(contract));
      } else {
        context.read<ContractBloc>().add(UpdateContract(contract));
      }

      await PdfContractService.generateAndDownloadContract(
        customerName: contract.customerName,
        customerAddress: selectedCustomer.address,
        customerContact: selectedCustomer.mobileNumber,
        oneTimeFees: contract.oneTimeFees,
        price200ml: contract.price200ml,
        moq200ml: contract.moq200ml,
        price500ml: contract.price500ml,
        moq500ml: contract.moq500ml,
        price1L: contract.price1L,
        moq1L: contract.moq1L,
        duration: contract.duration,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract PDF generated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Generate Contract'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
      ),
      body: BlocBuilder<CustomerBloc, CustomerState>(
        builder: (context, state) {
          List<CustomerModel> privateLabelCustomers = [];
          if (state is CustomersLoaded) {
            privateLabelCustomers = state.customers.where((c) => c.isPrivateLabel).toList();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Private Label Contract Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fill in the dynamic details to generate a formal PDF contract with rules and regulations.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Customer', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          hint: const Text('Choose a Custom Label Customer'),
                          value: _selectedCustomerId,
                          items: privateLabelCustomers.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.id,
                              child: Text('${c.shopName} (${c.mobileNumber})'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCustomerId = val),
                        ),
                        
                        const SizedBox(height: 24),
                        const Text('Financial Terms', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _oneTimeFeesController,
                          decoration: InputDecoration(
                            labelText: 'One-Time Setup / Label Fee (₹)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.currency_rupee),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildBottleOption(
                          'Include 200ml Crate',
                          _include200ml,
                          (val) => setState(() => _include200ml = val!),
                          _price200mlController,
                          _moq200mlController,
                        ),
                        const SizedBox(height: 8),
                        _buildBottleOption(
                          'Include 500ml Crate',
                          _include500ml,
                          (val) => setState(() => _include500ml = val!),
                          _price500mlController,
                          _moq500mlController,
                        ),
                        const SizedBox(height: 8),
                        _buildBottleOption(
                          'Include 1L Crate',
                          _include1L,
                          (val) => setState(() => _include1L = val!),
                          _price1LController,
                          _moq1LController,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contractDurationController,
                          decoration: InputDecoration(
                            labelText: 'Contract Duration',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            hintText: 'e.g. 12 Months',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isGenerating ? null : () => _generatePdf(privateLabelCustomers),
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _isGenerating ? 'Saving & Generating...' : 'Save & Download Contract',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottleOption(String title, bool isSelected, ValueChanged<bool?> onChanged, TextEditingController priceController, TextEditingController moqController) {
    return Row(
      children: [
        Checkbox(value: isSelected, onChanged: onChanged),
        Expanded(flex: 2, child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        if (isSelected) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: 'Price (₹)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: moqController,
              decoration: InputDecoration(
                labelText: 'MOQ (Crates)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ],
    );
  }
}
