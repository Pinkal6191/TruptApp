import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/models/expense_model.dart';

class AdminPartnerExpensesScreen extends StatelessWidget {
  const AdminPartnerExpensesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner Expenses', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A237E),
        iconTheme: const IconThemeData(color: Colors.white),
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
            return const Center(child: Text('No partner expenses found.'));
          }

          var expenses = snapshot.data!.docs
              .map((doc) => ExpenseModel.fromFirestore(doc))
              .where((e) => e.userId != null)
              .toList();
              
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

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF1A237E).withValues(alpha: 0.05),
                child: Column(
                  children: [
                    const Text('All Partners Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
                    return _ExpenseCard(expense: expense);
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
