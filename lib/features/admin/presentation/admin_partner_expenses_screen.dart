import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/models/expense_model.dart';

class AdminPartnerExpensesScreen extends StatefulWidget {
  const AdminPartnerExpensesScreen({Key? key}) : super(key: key);

  @override
  State<AdminPartnerExpensesScreen> createState() => _AdminPartnerExpensesScreenState();
}

class _AdminPartnerExpensesScreenState extends State<AdminPartnerExpensesScreen> {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Partner Expenses', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('expenses').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No partner expenses found.'));
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

          double totalAmt = 0;
          double pendingAmt = 0;
          double settledAmt = 0;
          int totalCount = expenses.length;
          int pendingCount = 0;
          
          for (var e in expenses) {
            totalAmt += e.amount;
            if (e.status == 'Pending') {
               pendingAmt += e.amount;
               pendingCount++;
            }
            if (e.status == 'Approved' || e.status == 'Settled') settledAmt += e.amount;
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
                color: const Color(0xFF1A237E).withValues(alpha: 0.05),
                child: Column(
                  children: [
                    const Text('Summary Indicator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryStat('Total ($totalCount)', totalAmt, Colors.blue),
                        _SummaryStat('Pending ($pendingCount)', pendingAmt, Colors.orange),
                        _SummaryStat('Settled', settledAmt, Colors.green),
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
                              leading: const CircleAvatar(backgroundColor: Color(0xFF1A237E), child: Icon(Icons.person, color: Colors.white)),
                              children: partnerExpenses.map((expense) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: _ExpenseCard(expense: expense),
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

  const _ExpenseCard({Key? key, required this.expense}) : super(key: key);

  void _updateStatus(BuildContext context, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('expenses').doc(expense.id).update({
        'status': newStatus,
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Expense marked as $newStatus')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy - hh:mm a');
    
    Color statusColor = Colors.orange;
    if (expense.status == 'Approved') statusColor = Colors.green;
    if (expense.status == 'Rejected') statusColor = Colors.red;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  expense.userName ?? 'Unknown Partner',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    expense.status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Type: ${expense.type}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '₹${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Date: ${dateFormat.format(expense.date)}'),
            if (expense.type == 'Delivery' && expense.distanceKm != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('Distance: ${expense.distanceKm} KM', style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
            const SizedBox(height: 8),
            Text('Description / Place: ${expense.description}', style: const TextStyle(color: Colors.grey)),
            
            if (expense.status == 'Pending') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reject', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    onPressed: () => _updateStatus(context, 'Rejected'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Approve', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _updateStatus(context, 'Approved'),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}
