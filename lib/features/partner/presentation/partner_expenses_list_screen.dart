import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/models/expense_model.dart';
import 'add_partner_expense_screen.dart';

class PartnerExpensesListScreen extends StatefulWidget {
  const PartnerExpensesListScreen({Key? key}) : super(key: key);

  @override
  State<PartnerExpensesListScreen> createState() => _PartnerExpensesListScreenState();
}

class _PartnerExpensesListScreenState extends State<PartnerExpensesListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All'; // All, Pending, Approved, Rejected
  String _dateFilter = 'All'; // All, Daily, Monthly, Financial Year, Custom
  DateTimeRange? _customDateRange;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _customDateRange,
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _dateFilter = 'Custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Expenses', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPartnerExpenseScreen())),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No expenses logged yet. Tap + to add.'));
          }

          var expenses = snapshot.data!.docs
              .map((doc) => ExpenseModel.fromFirestore(doc))
              .where((e) => e.userId != null)
              .toList();

          // 1. Apply Status Filter
          if (_statusFilter != 'All') {
            expenses = expenses.where((e) {
              if (_statusFilter == 'Approved') {
                return e.status == 'Approved' || e.status == 'Settled';
              }
              return e.status == _statusFilter;
            }).toList();
          }

          // 2. Apply Date Filter
          final now = DateTime.now();
          if (_dateFilter == 'Daily') {
            final today = DateTime(now.year, now.month, now.day);
            expenses = expenses.where((e) {
              final date = DateTime(e.date.year, e.date.month, e.date.day);
              return date.isAtSameMomentAs(today);
            }).toList();
          } else if (_dateFilter == 'Monthly') {
            expenses = expenses.where((e) {
              return e.date.year == now.year && e.date.month == now.month;
            }).toList();
          } else if (_dateFilter == 'Financial Year') {
            int fyStartYear = now.month >= 4 ? now.year : now.year - 1;
            final fyStart = DateTime(fyStartYear, 4, 1);
            final fyEnd = DateTime(fyStartYear + 1, 3, 31);
            expenses = expenses.where((e) {
              final date = DateTime(e.date.year, e.date.month, e.date.day);
              return (date.isAtSameMomentAs(fyStart) || date.isAfter(fyStart)) &&
                     (date.isAtSameMomentAs(fyEnd) || date.isBefore(fyEnd));
            }).toList();
          } else if (_dateFilter == 'Custom' && _customDateRange != null) {
            final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
            final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day);
            expenses = expenses.where((e) {
              final date = DateTime(e.date.year, e.date.month, e.date.day);
              return (date.isAtSameMomentAs(start) || date.isAfter(start)) &&
                     (date.isAtSameMomentAs(end) || date.isBefore(end));
            }).toList();
          }

          // 3. Apply Search Query Filter
          final query = _searchQuery.toLowerCase().trim();
          if (query.isNotEmpty) {
            expenses = expenses.where((e) {
              final matchName = (e.userName ?? '').toLowerCase().contains(query);
              final matchType = e.type.toLowerCase().contains(query);
              final matchDesc = e.description.toLowerCase().contains(query);
              return matchName || matchType || matchDesc;
            }).toList();
          }
          
          expenses.sort((a, b) => b.date.compareTo(a.date));

          double total = 0;
          double approved = 0;
          double pending = 0;
          
          for (var e in expenses) {
            total += e.amount;
            if (e.status == 'Approved' || e.status == 'Settled') approved += e.amount;
            if (e.status == 'Pending') pending += e.amount;
          }

          final Map<String, List<ExpenseModel>> groupedExpenses = {};
          for (var e in expenses) {
            final name = e.userName ?? 'Unknown Partner';
            if (!groupedExpenses.containsKey(name)) {
              groupedExpenses[name] = [];
            }
            groupedExpenses[name]!.add(e);
          }

          return Column(
            children: [
              // Search & Filter Header Card
              Card(
                margin: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search field
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search partner, type or place...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      // Dropdown filter row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _statusFilter,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              items: ['All', 'Pending', 'Approved', 'Rejected'].map((status) {
                                return DropdownMenuItem(value: status, child: Text(status));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _statusFilter = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _dateFilter,
                              decoration: const InputDecoration(
                                labelText: 'Period',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              items: ['All', 'Daily', 'Monthly', 'Financial Year', 'Custom'].map((period) {
                                return DropdownMenuItem(value: period, child: Text(period));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  if (val == 'Custom') {
                                    _selectCustomDateRange();
                                  } else {
                                    setState(() => _dateFilter = val);
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.teal.shade50,
                child: Column(
                  children: [
                    const Text('Expense Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryStat('Total', total, Colors.blue),
                        _SummaryStat('Approved', approved, Colors.green),
                        _SummaryStat('Pending', pending, Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: expenses.isEmpty
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No expenses found matching the search/filter criteria.', style: TextStyle(color: Colors.grey)),
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: groupedExpenses.keys.length,
                        itemBuilder: (context, index) {
                          final partnerName = groupedExpenses.keys.elementAt(index);
                          final partnerExpenses = groupedExpenses[partnerName]!;
                          
                          double partnerTotal = 0;
                          for(var e in partnerExpenses) {
                            partnerTotal += e.amount;
                          }
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ExpansionTile(
                              title: Text(partnerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${partnerExpenses.length} log(s) | Total: ₹${partnerTotal.toStringAsFixed(2)}'),
                              leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white)),
                              children: partnerExpenses.map((expense) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: _ExpenseCard(expense: expense, currentUserId: user.uid),
                              )).toList(),
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

class _SummaryStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryStat(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
      ],
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final ExpenseModel expense;
  final String currentUserId;

  const _ExpenseCard({Key? key, required this.expense, required this.currentUserId}) : super(key: key);

  void _deleteExpense(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('expenses').doc(expense.id).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    
    Color statusColor = Colors.orange;
    if (expense.status == 'Approved' || expense.status == 'Settled') statusColor = Colors.green;
    if (expense.status == 'Rejected') statusColor = Colors.red;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Type: ${expense.type}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(expense.userName ?? 'Unknown Partner', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14)),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        expense.status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    if (expense.status == 'Pending' && expense.userId == currentUserId)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (value) {
                          if (value == 'Edit') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AddPartnerExpenseScreen(existingExpense: expense)));
                          } else if (value == 'Delete') {
                            _deleteExpense(context);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'Edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'Delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dateFormat.format(expense.date), style: const TextStyle(color: Colors.grey)),
                Text(
                  '₹${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                ),
              ],
            ),
            if (expense.type == 'Delivery' && expense.distanceKm != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Distance: ${expense.distanceKm} KM', style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
            if (expense.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Details: ${expense.description}', style: const TextStyle(color: Colors.black87)),
              ),
          ],
        ),
      ),
    );
  }
}
