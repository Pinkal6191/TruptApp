import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/services/settings_service.dart';

class AddPartnerExpenseScreen extends StatefulWidget {
  const AddPartnerExpenseScreen({Key? key}) : super(key: key);

  @override
  State<AddPartnerExpenseScreen> createState() => _AddPartnerExpenseScreenState();
}

class _AddPartnerExpenseScreenState extends State<AddPartnerExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  
  String _selectedType = 'Delivery';
  final List<String> _types = ['Delivery', 'Transport', 'Extra'];
  
  bool _isLoading = false;
  double _deliveryRate = 10.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _distanceCtrl.addListener(_calculateDeliveryAmount);
  }

  @override
  void dispose() {
    _distanceCtrl.removeListener(_calculateDeliveryAmount);
    _distanceCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService().getSettings();
    setState(() {
      _deliveryRate = settings.partnerDeliveryRatePerKm;
    });
  }

  void _calculateDeliveryAmount() {
    if (_selectedType == 'Delivery') {
      final distance = double.tryParse(_distanceCtrl.text) ?? 0.0;
      final amount = distance * _deliveryRate;
      _amountCtrl.text = amount.toStringAsFixed(2);
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Get user name (optional but helpful)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] as String? ?? 'Partner';

      final amount = double.parse(_amountCtrl.text);
      final distance = _selectedType == 'Delivery' ? double.tryParse(_distanceCtrl.text) : null;

      final expenseRef = FirebaseFirestore.instance.collection('expenses').doc();
      final expense = ExpenseModel(
        id: expenseRef.id,
        type: _selectedType,
        amount: amount,
        date: DateTime.now(),
        description: _descCtrl.text.trim(),
        userId: user.uid,
        userName: userName,
        distanceKm: distance,
        status: 'Pending',
      );

      await expenseRef.set(expense.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense submitted for approval!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Expense Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedType = val!;
                    if (_selectedType != 'Delivery') {
                      _amountCtrl.clear();
                    } else {
                      _calculateDeliveryAmount();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              if (_selectedType == 'Delivery') ...[
                const Text('Distance Traveled (KM)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _distanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 15.5',
                    suffixText: 'KM',
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Required for delivery' : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: Text('Rate: ₹$_deliveryRate per KM (Set by Admin)', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                ),
              ],

              const Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                readOnly: _selectedType == 'Delivery', // Read-only if Delivery
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  filled: _selectedType == 'Delivery',
                  fillColor: _selectedType == 'Delivery' ? Colors.grey.shade200 : null,
                ),
                validator: (val) => val == null || val.isEmpty ? 'Enter amount' : null,
              ),
              const SizedBox(height: 16),

              const Text('Details (Place, Time, Reason)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Delivery to City Center at 2 PM using personal car.',
                ),
                validator: (val) => val == null || val.isEmpty ? 'Enter details' : null,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Expense', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
