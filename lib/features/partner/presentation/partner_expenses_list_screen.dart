import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/models/expense_model.dart';
import 'add_partner_expense_screen.dart';

class PartnerExpensesListScreen extends StatelessWidget {
  const PartnerExpensesListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Not logged in')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Expenses', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPartnerExpenseScreen())),
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('expenses')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No expenses logged yet. Tap + to add.'));
          }

          final expenses = snapshot.data!.docs
              .map((doc) => ExpenseModel.fromFirestore(doc))
              .where((e) => e.userId != null)
              .toList();
          
          // Sort locally to avoid needing a Firestore Composite Index
          expenses.sort((a, b) => b.date.compareTo(a.date));

          double total = 0;
          double approved = 0;
          double pending = 0;
          
          for (var e in expenses) {
            total += e.amount;
            if (e.status == 'Approved' || e.status == 'Settled') approved += e.amount;
            if (e.status == 'Pending') pending += e.amount;
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.teal.shade50,
                child: Column(
                  children: [
                    const Text('Expense Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return _ExpenseCard(expense: expense, currentUserId: user.uid);
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
