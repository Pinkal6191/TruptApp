import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/utils/route_tracker.dart';
import '../bloc/expense_bloc.dart';
import '../bloc/expense_event.dart';
import '../bloc/expense_state.dart';

class ExpenseManagementScreen extends StatefulWidget {
  const ExpenseManagementScreen({super.key});

  @override
  State<ExpenseManagementScreen> createState() => _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends State<ExpenseManagementScreen> {
  String _searchQuery = '';
  String _dateFilter = 'All'; // All, Daily, Monthly, Financial Year, Custom
  DateTimeRange? _customDateRange;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('expense_management');
    context.read<ExpenseBloc>().add(LoadExpenses());
  }

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

  void _showAddExpenseModal() {
    final state = context.read<ExpenseBloc>().state;
    Set<String> uniqueTypes = {'Transport charge for delivery', 'Transport charge for material buy or delivered', 'Labor', 'Other'};
    if (state is ExpensesLoaded) {
      for (var exp in state.expenses) {
        uniqueTypes.add(exp.type);
      }
    }
    List<String> dropDownItems = uniqueTypes.toList();

    String type = dropDownItems.first;
    String customType = '';
    double amount = 0.0;
    String description = '';
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add New Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: dropDownItems.contains(type) ? type : dropDownItems.first,
                    decoration: const InputDecoration(labelText: 'Expense Type', border: OutlineInputBorder()),
                    isExpanded: true,
                    items: dropDownItems.map((String val) {
                      return DropdownMenuItem(value: val, child: Text(val));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => type = val);
                      }
                    },
                  ),
                  if (type == 'Other') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Enter Custom Type', border: OutlineInputBorder()),
                      onChanged: (val) {
                        customType = val;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        amount = double.parse(val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    onChanged: (val) {
                      description = val;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setModalState(() => selectedDate = pickedDate);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Color(0xFF1E3A8A), size: 20),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('dd MMM yyyy').format(selectedDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const Text('Change', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (amount > 0) {
                          String finalType = type == 'Other' ? (customType.isNotEmpty ? customType : 'Other') : type;
                          final expense = ExpenseModel(
                            id: '',
                            type: finalType,
                            amount: amount,
                            date: selectedDate,
                            description: description,
                          );
                          context.read<ExpenseBloc>().add(AddExpense(expense: expense));
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Save Expense'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditExpenseModal(ExpenseModel expense) {
    final state = context.read<ExpenseBloc>().state;
    Set<String> uniqueTypes = {'Transport charge for delivery', 'Transport charge for material buy or delivered', 'Labor', 'Other'};
    if (state is ExpensesLoaded) {
      for (var exp in state.expenses) {
        uniqueTypes.add(exp.type);
      }
    }
    uniqueTypes.add(expense.type);
    List<String> dropDownItems = uniqueTypes.toList();

    String type = dropDownItems.contains(expense.type) ? expense.type : 'Other';
    String customType = '';
    double amount = expense.amount;
    String description = expense.description;
    DateTime selectedDate = expense.date;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit Expense', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: dropDownItems.contains(type) ? type : dropDownItems.first,
                    decoration: const InputDecoration(labelText: 'Expense Type', border: OutlineInputBorder()),
                    isExpanded: true,
                    items: dropDownItems.map((String val) {
                      return DropdownMenuItem(value: val, child: Text(val));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => type = val);
                      }
                    },
                  ),
                  if (type == 'Other') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Enter Custom Type', border: OutlineInputBorder()),
                      onChanged: (val) {
                        customType = val;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: amount.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                    onChanged: (val) {
                      if (val.isNotEmpty) {
                        amount = double.parse(val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: description,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    onChanged: (val) {
                      description = val;
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setModalState(() => selectedDate = pickedDate);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Color(0xFF1E3A8A), size: 20),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('dd MMM yyyy').format(selectedDate),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const Text('Change', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (amount > 0) {
                          String finalType = type == 'Other' ? (customType.isNotEmpty ? customType : 'Other') : type;
                          final updatedExpense = ExpenseModel(
                            id: expense.id,
                            type: finalType,
                            amount: amount,
                            date: selectedDate,
                            description: description,
                          );
                          context.read<ExpenseBloc>().add(UpdateExpense(expense: updatedExpense));
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Update Expense'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showConfirmDeleteDialog(ExpenseModel expense) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Expense', style: TextStyle(color: Color(0xFF1E3A8A))),
          content: Text('Are you sure you want to delete this expense of ₹${expense.amount.toStringAsFixed(2)}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                context.read<ExpenseBloc>().add(DeleteExpense(id: expense.id));
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  IconData _getExpenseIcon(String type) {
    switch (type) {
      case 'Transport': return Icons.local_shipping;
      case 'Labor': return Icons.construction;
      default: return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Expense Management'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF10B981),
        onPressed: _showAddExpenseModal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: BlocConsumer<ExpenseBloc, ExpenseState>(
        listener: (context, state) {
          if (state is ExpenseOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.green));
          } else if (state is ExpenseError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        builder: (context, state) {
          if (state is ExpenseLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ExpensesLoaded) {
            var filteredExpenses = List<ExpenseModel>.from(state.expenses);

            // 1. Apply Date Filter
            final now = DateTime.now();
            if (_dateFilter == 'Daily') {
              final today = DateTime(now.year, now.month, now.day);
              filteredExpenses = filteredExpenses.where((e) {
                final date = DateTime(e.date.year, e.date.month, e.date.day);
                return date.isAtSameMomentAs(today);
              }).toList();
            } else if (_dateFilter == 'Monthly') {
              filteredExpenses = filteredExpenses.where((e) {
                return e.date.year == now.year && e.date.month == now.month;
              }).toList();
            } else if (_dateFilter == 'Financial Year') {
              int fyStartYear = now.month >= 4 ? now.year : now.year - 1;
              final fyStart = DateTime(fyStartYear, 4, 1);
              final fyEnd = DateTime(fyStartYear + 1, 3, 31);
              filteredExpenses = filteredExpenses.where((e) {
                final date = DateTime(e.date.year, e.date.month, e.date.day);
                return (date.isAtSameMomentAs(fyStart) || date.isAfter(fyStart)) &&
                       (date.isAtSameMomentAs(fyEnd) || date.isBefore(fyEnd));
              }).toList();
            } else if (_dateFilter == 'Custom' && _customDateRange != null) {
              final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
              final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day);
              filteredExpenses = filteredExpenses.where((e) {
                final date = DateTime(e.date.year, e.date.month, e.date.day);
                return (date.isAtSameMomentAs(start) || date.isAfter(start)) &&
                       (date.isAtSameMomentAs(end) || date.isBefore(end));
              }).toList();
            }

            // 2. Apply Search Filter
            final query = _searchQuery.toLowerCase().trim();
            if (query.isNotEmpty) {
              filteredExpenses = filteredExpenses.where((e) {
                final matchType = e.type.toLowerCase().contains(query);
                final matchDesc = e.description.toLowerCase().contains(query);
                return matchType || matchDesc;
              }).toList();
            }

            double totalExpense = filteredExpenses.fold(0, (sum, item) => sum + item.amount);

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Expenses', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('₹${totalExpense.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Search & Filter Card
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search type or description...',
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
                        DropdownButtonFormField<String>(
                          value: _dateFilter,
                          decoration: const InputDecoration(
                            labelText: 'Period Filter',
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
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: filteredExpenses.isEmpty
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text('No expenses found matching search/filter.', style: TextStyle(color: Colors.grey)),
                        ))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredExpenses.length,
                          itemBuilder: (context, index) {
                            final expense = filteredExpenses[index];
                            return Card(
                              elevation: 1,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                                  child: Icon(_getExpenseIcon(expense.type), color: const Color(0xFF3B82F6)),
                                ),
                                title: Text(expense.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${DateFormat('MMM dd, yyyy').format(expense.date)}${expense.description.isNotEmpty ? ' • ${expense.description}' : ''}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('-₹${expense.amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 20),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _showEditExpenseModal(expense);
                                        } else if (value == 'delete') {
                                          _showConfirmDeleteDialog(expense);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit, color: Colors.blue, size: 18),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete, color: Colors.red, size: 18),
                                              SizedBox(width: 8),
                                              Text('Delete'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
