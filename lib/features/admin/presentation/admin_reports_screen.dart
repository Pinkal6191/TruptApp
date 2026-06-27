import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/utils/file_downloader.dart';
import '../../../core/utils/route_tracker.dart';
import '../../orders/bloc/order_bloc.dart';
import '../../orders/bloc/order_event.dart';
import '../../orders/bloc/order_state.dart';
import '../../expenses/bloc/expense_bloc.dart';
import '../../expenses/bloc/expense_event.dart';
import '../../expenses/bloc/expense_state.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _reportType = 'all'; // all, partner, distributor, customer, order_wise, expense
  DateTimeRange? _dateRange;
  String _periodFilter = 'All'; // All, Daily, Monthly, Financial Year, Custom
  String _sortOrder = 'Sales Desc'; // Default to Sales Desc for aggregated, will switch to Date Desc for order_wise/expense

  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('admin_reports');
    context.read<OrderBloc>().add(LoadAllOrders());
    context.read<ExpenseBloc>().add(LoadExpenses());
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _periodFilter = 'Custom';
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _reportType = 'all';
      _dateRange = null;
      _periodFilter = 'All';
      _sortOrder = 'Sales Desc';
    });
  }

  void _onReportTypeChanged(String newType) {
    setState(() {
      _reportType = newType;
      if (newType == 'order_wise' || newType == 'expense') {
        _sortOrder = 'Date Desc';
      } else {
        _sortOrder = 'Sales Desc';
      }
    });
  }

  List<DropdownMenuItem<String>> _getSortItems() {
    if (_reportType == 'order_wise') {
      return const [
        DropdownMenuItem(value: 'Date Desc', child: Text('Date (Newest)')),
        DropdownMenuItem(value: 'Date Asc', child: Text('Date (Oldest)')),
        DropdownMenuItem(value: 'Invoice Asc', child: Text('Invoice (Asc)')),
        DropdownMenuItem(value: 'Invoice Desc', child: Text('Invoice (Desc)')),
        DropdownMenuItem(value: 'Sales Desc', child: Text('Sales (High First)')),
        DropdownMenuItem(value: 'Sales Asc', child: Text('Sales (Low First)')),
      ];
    } else if (_reportType == 'expense') {
      return const [
        DropdownMenuItem(value: 'Date Desc', child: Text('Date (Newest)')),
        DropdownMenuItem(value: 'Date Asc', child: Text('Date (Oldest)')),
        DropdownMenuItem(value: 'Amount Desc', child: Text('Amount (High First)')),
        DropdownMenuItem(value: 'Amount Asc', child: Text('Amount (Low First)')),
      ];
    } else {
      return const [
        DropdownMenuItem(value: 'Sales Desc', child: Text('Sales (High First)')),
        DropdownMenuItem(value: 'Sales Asc', child: Text('Sales (Low First)')),
        DropdownMenuItem(value: 'Name Asc', child: Text('Name (A-Z)')),
        DropdownMenuItem(value: 'Name Desc', child: Text('Name (Z-A)')),
      ];
    }
  }

  List<ExpenseModel> _processExpenses(List<ExpenseModel> rawExpenses) {
    List<ExpenseModel> filtered = rawExpenses;
    if (_periodFilter == 'Daily') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      filtered = filtered.where((e) {
        final date = DateTime(e.date.year, e.date.month, e.date.day);
        return date.isAtSameMomentAs(today);
      }).toList();
    } else if (_periodFilter == 'Monthly') {
      final now = DateTime.now();
      filtered = filtered.where((e) {
        return e.date.year == now.year && e.date.month == now.month;
      }).toList();
    } else if (_periodFilter == 'Financial Year') {
      final now = DateTime.now();
      int fyStartYear = now.month >= 4 ? now.year : now.year - 1;
      final fyStart = DateTime(fyStartYear, 4, 1);
      final fyEnd = DateTime(fyStartYear + 1, 3, 31);
      filtered = filtered.where((e) {
        final date = DateTime(e.date.year, e.date.month, e.date.day);
        return (date.isAtSameMomentAs(fyStart) || date.isAfter(fyStart)) &&
               (date.isAtSameMomentAs(fyEnd) || date.isBefore(fyEnd));
      }).toList();
    } else if (_periodFilter == 'Custom' && _dateRange != null) {
      final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
      final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
      filtered = filtered.where((e) {
        final date = DateTime(e.date.year, e.date.month, e.date.day);
        return (date.isAtSameMomentAs(start) || date.isAfter(start)) &&
               (date.isAtSameMomentAs(end) || date.isBefore(end));
      }).toList();
    }

    List<ExpenseModel> sorted = List.from(filtered);
    if (_sortOrder == 'Date Asc') {
      sorted.sort((a, b) => a.date.compareTo(b.date));
    } else if (_sortOrder == 'Amount Asc') {
      sorted.sort((a, b) => a.amount.compareTo(b.amount));
    } else if (_sortOrder == 'Amount Desc') {
      sorted.sort((a, b) => b.amount.compareTo(a.amount));
    } else {
      // Date Desc
      sorted.sort((a, b) => b.date.compareTo(a.date));
    }
    return sorted;
  }

  List<Map<String, dynamic>> _processData(List<OrderModel> orders) {
    // Exclude distributor individual retail orders to avoid duplicate/inflated calculations
    List<OrderModel> filtered = orders.where((o) => !(o.creatorRole == 'distributor' && !o.isSupplyOrder)).toList();

    if (_periodFilter == 'Daily') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      filtered = filtered.where((o) {
        final date = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
        return date.isAtSameMomentAs(today);
      }).toList();
    } else if (_periodFilter == 'Monthly') {
      final now = DateTime.now();
      filtered = filtered.where((o) {
        return o.createdAt.year == now.year && o.createdAt.month == now.month;
      }).toList();
    } else if (_periodFilter == 'Financial Year') {
      final now = DateTime.now();
      int fyStartYear = now.month >= 4 ? now.year : now.year - 1;
      final fyStart = DateTime(fyStartYear, 4, 1);
      final fyEnd = DateTime(fyStartYear + 1, 3, 31);
      filtered = filtered.where((o) {
        final date = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
        return (date.isAtSameMomentAs(fyStart) || date.isAfter(fyStart)) &&
               (date.isAtSameMomentAs(fyEnd) || date.isBefore(fyEnd));
      }).toList();
    } else if (_periodFilter == 'Custom' && _dateRange != null) {
      final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
      final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
      filtered = filtered.where((o) {
        final date = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
        return (date.isAtSameMomentAs(start) || date.isAfter(start)) &&
               (date.isAtSameMomentAs(end) || date.isBefore(end));
      }).toList();
    }

    if (_reportType == 'partner') {
      filtered = filtered.where((o) =>
        o.creatorRole == 'partner' ||
        (o.creatorRole == 'admin' && o.orderReference != 'Direct (Online / Call)')
      ).toList();
    } else if (_reportType == 'distributor') {
      filtered = filtered.where((o) => o.isSupplyOrder).toList();
    }

    if (_reportType == 'order_wise') {
      List<OrderModel> sorted = List.from(filtered);
      if (_sortOrder == 'Date Asc') {
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      } else if (_sortOrder == 'Invoice Asc') {
        sorted.sort((a, b) => a.invoiceNumber.compareTo(b.invoiceNumber));
      } else if (_sortOrder == 'Invoice Desc') {
        sorted.sort((a, b) => b.invoiceNumber.compareTo(a.invoiceNumber));
      } else if (_sortOrder == 'Sales Asc') {
        sorted.sort((a, b) => a.finalAmount.compareTo(b.finalAmount));
      } else if (_sortOrder == 'Sales Desc') {
        sorted.sort((a, b) => b.finalAmount.compareTo(a.finalAmount));
      } else {
        // Date Desc
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      
      return sorted.map((o) {
        String crateDetails = o.items.map((item) {
          double gross = item.quantity * item.pricePerCrate;
          double taxable = gross / 1.05;
          double gst = gross - taxable;
          return '${item.productName} - ${item.quantity} caret - Rs. ${gross.toStringAsFixed(2)} - GST Rs. ${gst.toStringAsFixed(2)} (Incl.) - Rs. ${taxable.toStringAsFixed(2)}';
        }).join('\n');
        
        Map<String, int> itemsMap = {};
        Map<String, String> itemsDetailsMap = {};
        for (var item in o.items) {
          itemsMap[item.productName] = item.quantity;
          double gross = item.quantity * item.pricePerCrate;
          double taxable = gross / 1.05;
          double gst = gross - taxable;
          itemsDetailsMap[item.productName] = '${item.quantity} caret - Rs. ${gross.toStringAsFixed(2)} - GST Rs. ${gst.toStringAsFixed(2)} - Rs. ${taxable.toStringAsFixed(2)}';
        }

        return {
          'name': o.shopName.isNotEmpty ? o.shopName : o.partnerName,
          'invoiceNumber': o.invoiceNumber.isNotEmpty ? o.invoiceNumber : 'N/A',
          'date': DateFormat('dd/MM/yyyy').format(o.createdAt),
          'customerGst': o.customerGstNumber.isNotEmpty ? o.customerGstNumber : 'N/A',
          'subtotal': o.subtotal,
          'gstAmount': o.gstAmount,
          'sales': o.finalAmount,
          'paid': o.paidAmount,
          'orders': 1,
          'paymentStatus': o.paymentStatus,
          'partnerName': o.partnerName,
          'crateDetails': crateDetails,
          'itemsMap': itemsMap,
          'itemsDetailsMap': itemsDetailsMap,
          'isOrderWise': true,
        };
      }).toList();
    }

    Map<String, Map<String, dynamic>> aggregated = {};

    for (var o in filtered) {
      String key;
      if (_reportType == 'customer') {
        key = o.shopName.isNotEmpty ? o.shopName : o.partnerName;
      } else if (_reportType == 'partner') {
        key = (o.creatorRole == 'admin' && o.orderReference != 'Direct (Online / Call)')
            ? o.orderReference
            : o.partnerName;
      } else {
        key = o.partnerName;
      }

      if (!aggregated.containsKey(key)) {
        aggregated[key] = {'name': key, 'orders': 0, 'sales': 0.0, 'paid': 0.0, 'commission': 0.0};
      }
      
      double commission = 0.0;
      if (o.isSupplyOrder) {
        for (var item in o.items) {
          if (item.pricePerCrate > item.distributorCost && item.distributorCost > 0) {
            commission += ((item.pricePerCrate - item.distributorCost) * item.quantity);
          }
        }
      }

      aggregated[key]!['orders'] = (aggregated[key]!['orders'] as int) + 1;
      aggregated[key]!['sales'] = (aggregated[key]!['sales'] as double) + o.finalAmount;
      aggregated[key]!['paid'] = (aggregated[key]!['paid'] as double) + o.paidAmount;
      aggregated[key]!['commission'] = (aggregated[key]!['commission'] as double) + commission;
    }

    var resultList = aggregated.values.toList();
    if (_sortOrder == 'Sales Asc') {
      resultList.sort((a, b) => (a['sales'] as double).compareTo(b['sales'] as double));
    } else if (_sortOrder == 'Name Asc') {
      resultList.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    } else if (_sortOrder == 'Name Desc') {
      resultList.sort((a, b) => (b['name'] as String).compareTo(a['name'] as String));
    } else {
      // Sales Desc
      resultList.sort((a, b) => (b['sales'] as double).compareTo(a['sales'] as double));
    }
    return resultList;
  }

  String _getDateRangeDescription() {
    if (_periodFilter == 'Daily') {
      return 'Daily Report - ${DateFormat('dd/MM/yyyy').format(DateTime.now())}';
    } else if (_periodFilter == 'Monthly') {
      return 'Monthly Report - ${DateFormat('MMMM yyyy').format(DateTime.now())}';
    } else if (_periodFilter == 'Financial Year') {
      final now = DateTime.now();
      int fyStartYear = now.month >= 4 ? now.year : now.year - 1;
      return 'Financial Year Report - FY $fyStartYear-${((fyStartYear + 1) % 100).toString().padLeft(2, '0')}';
    }

    if (_dateRange == null) {
      return 'All Time Report';
    }
    
    final start = _dateRange!.start;
    final end = _dateRange!.end;
    
    bool isLastDayOfMonth(DateTime date) {
      final nextMonth = DateTime(date.year, date.month + 1, 1);
      final lastDay = nextMonth.subtract(const Duration(days: 1));
      return date.day == lastDay.day;
    }
    
    // Check for Full Calendar Month (e.g. 1st to end of the month)
    if (start.day == 1 && isLastDayOfMonth(end) && start.month == end.month && start.year == end.year) {
      return 'Monthly Report - ${DateFormat('MMMM yyyy').format(start)}';
    }

    if (_reportType == 'expense') {
      return 'Expense Report';
    }
    
    // Check for Indian Financial Year (April 1 to March 31 of next year)
    if (start.day == 1 && start.month == DateTime.april && end.day == 31 && end.month == DateTime.march && end.year == start.year + 1) {
      final fyStart = start.year;
      final fyEnd = (start.year + 1) % 100;
      return 'Financial Year Report - FY $fyStart-${fyEnd.toString().padLeft(2, '0')}';
    }
    
    // Check for Calendar Year (Jan 1 to Dec 31)
    if (start.day == 1 && start.month == DateTime.january && end.day == 31 && end.month == DateTime.december && start.year == end.year) {
      return 'Yearly Report - ${start.year}';
    }
    
    // Custom Date Range fallback
    final startStr = DateFormat('dd/MM/yyyy').format(start);
    final endStr = DateFormat('dd/MM/yyyy').format(end);
    return 'Period: $startStr to $endStr';
  }

  String _getReportTypeName() {
    switch (_reportType) {
      case 'all': return 'All Orders Summary';
      case 'order_wise': return 'Order-wise (GST)';
      case 'partner': return 'Partner-wise';
      case 'distributor': return 'Distributor-wise';
      case 'customer': return 'Customer-wise';
      case 'expense': return 'Expense Report';
      default: return 'Report';
    }
  }

  Future<void> _exportCsv(List<Map<String, dynamic>> data) async {
    List<List<dynamic>> rows = [
      ['TRUPT ENTERPRISE'],
      ['Address: 4160, B/H Mahalaxmi Cold Storage, Boriavi, Anand - 387310'],
      ['Phone: +91 96624 98664, +91 98793 95727'],
      ['Email: truptenterprise26@gmail.com', 'Website: truptenterprise.com'],
      ['GSTIN: 24AAZFT5241K1ZK'],
      [],
      ['BUSINESS REPORT: ${_getReportTypeName()}'],
      ['Period: ${_getDateRangeDescription()}'],
      ['Generated On: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'],
      [],
    ];

    if (_reportType == 'order_wise') {
      Set<String> productNames = {};
      for (var row in data) {
        if (row['itemsMap'] != null) {
          productNames.addAll((row['itemsMap'] as Map<String, int>).keys);
        }
      }
      List<String> sortedProducts = productNames.toList()..sort();

      List<dynamic> headerRow = [
        'Invoice No',
        'Date',
        'Customer/Shop Name',
        'GST Number',
      ];
      headerRow.addAll(sortedProducts);
      headerRow.addAll([
        'Subtotal (Excl. GST)',
        'GST Rate',
        'GST Amount',
        'Total (Incl. GST)',
        'Paid Amount',
        'Balance Amount',
        'Payment Status'
      ]);
      rows.add(headerRow);

      for (var row in data) {
        double subtotal = row['subtotal'] ?? 0.0;
        double gstAmount = row['gstAmount'] ?? 0.0;
        double sales = row['sales'] ?? 0.0;
        double paid = row['paid'] ?? 0.0;
        double balance = sales - paid;
        
        Map<String, String> itemsDetailsMap = Map<String, String>.from(row['itemsDetailsMap'] ?? {});

        List<dynamic> dataRow = [
          row['invoiceNumber'] ?? '',
          row['date'] ?? '',
          row['name'] ?? '',
          row['customerGst'] ?? '',
        ];
        
        for (String product in sortedProducts) {
          dataRow.add(itemsDetailsMap[product] ?? '0');
        }

        dataRow.addAll([
          subtotal.toStringAsFixed(2),
          '5%',
          gstAmount.toStringAsFixed(2),
          sales.toStringAsFixed(2),
          paid.toStringAsFixed(2),
          balance.toStringAsFixed(2),
          row['paymentStatus'] ?? ''
        ]);
        
        rows.add(dataRow);
      }
    } else if (_reportType == 'expense') {
      final expenseState = context.read<ExpenseBloc>().state;
      if (expenseState is ExpensesLoaded) {
        var expenses = _processExpenses(expenseState.expenses);
        rows.add(['Date', 'Type', 'Amount', 'Description', 'User']);
        for (var e in expenses) {
          rows.add([
            DateFormat('dd/MM/yyyy').format(e.date),
            e.type,
            e.amount.toStringAsFixed(2),
            e.description ?? '',
            e.userName ?? '',
          ]);
        }
      }
    } else {
      if (_reportType == 'distributor') {
        rows.add(['Name', 'Total Orders', 'Total Sales', 'Commission', 'Total Paid', 'Balance']);
        for (var row in data) {
          double sales = row['sales'];
          double paid = row['paid'];
          double comm = row['commission'] ?? 0.0;
          rows.add([
            row['name'],
            row['orders'],
            sales.toStringAsFixed(2),
            comm.toStringAsFixed(2),
            paid.toStringAsFixed(2),
            (sales - paid).toStringAsFixed(2)
          ]);
        }
      } else {
        rows.add(['Name', 'Total Orders', 'Total Sales', 'Total Paid', 'Balance']);
        for (var row in data) {
          double sales = row['sales'];
          double paid = row['paid'];
          rows.add([
            row['name'],
            row['orders'],
            sales.toStringAsFixed(2),
            paid.toStringAsFixed(2),
            (sales - paid).toStringAsFixed(2)
          ]);
        }
      }
    }

    String csvData = Csv().encode(rows);
    final bytes = utf8.encode(csvData);
    final fileName = 'Business_Report_${DateTime.now().millisecondsSinceEpoch}.csv';
    
    await downloadFile(bytes, fileName, mimeType: 'text/csv');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV Downloaded')));
    }
  }

  Future<void> _exportPdf(List<Map<String, dynamic>> data, double totalSales) async {
    final pdf = pw.Document();
    
    List<String> sortedProducts = [];
    if (_reportType == 'order_wise') {
      Set<String> productNames = {};
      for (var row in data) {
        if (row['itemsMap'] != null) {
          productNames.addAll((row['itemsMap'] as Map<String, int>).keys);
        }
      }
      sortedProducts = productNames.toList()..sort();
    }
    
    List<List<dynamic>> _buildPdfDataRows(List<Map<String, dynamic>> data) {
      if (_reportType == 'expense') {
        final expenseState = context.read<ExpenseBloc>().state;
        if (expenseState is ExpensesLoaded) {
          var expenses = _processExpenses(expenseState.expenses);
          return expenses.map((e) {
            return [
              DateFormat('dd/MM/yy').format(e.date),
              e.type,
              e.description ?? '',
              e.amount.toStringAsFixed(2),
            ];
          }).toList();
        }
        return [];
      }

      return data.map((row) {
        if (_reportType == 'order_wise') {
          double subtotal = row['subtotal'] ?? 0.0;
          double gstAmount = row['gstAmount'] ?? 0.0;
          double sales = row['sales'] ?? 0.0;
          double paid = row['paid'] ?? 0.0;
          double balance = sales - paid;
          Map<String, String> itemsDetailsMap = Map<String, String>.from(row['itemsDetailsMap'] ?? {});
          
          List<dynamic> dataRow = [
            row['invoiceNumber'] ?? '',
            row['date'] ?? '',
            row['name'] ?? '',
            row['customerGst'] ?? '',
          ];
          
          for (String product in sortedProducts) {
            dataRow.add(itemsDetailsMap[product] ?? '0');
          }
          
          dataRow.addAll([
            subtotal.toStringAsFixed(2),
            '5%',
            gstAmount.toStringAsFixed(2),
            sales.toStringAsFixed(2),
            paid.toStringAsFixed(2),
            balance.toStringAsFixed(2),
            row['paymentStatus'] ?? ''
          ]);
          return dataRow;
        } else if (_reportType == 'distributor') {
          return [
            row['name'],
            row['orders'].toString(),
            ((row['sales'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
            ((row['commission'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
            ((row['paid'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
            (((row['sales'] as num?)?.toDouble() ?? 0.0) - ((row['paid'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(2),
          ];
        } else {
          return [
            row['name'],
            row['orders'].toString(),
            ((row['sales'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
            ((row['paid'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
            (((row['sales'] as num?)?.toDouble() ?? 0.0) - ((row['paid'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(2),
          ];
        }
      }).toList();
    }

    Map<int, pw.Alignment> _buildPdfCellAlignments() {
      if (_reportType == 'expense') {
        return {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.centerRight,
        };
      } else if (_reportType == 'order_wise') {
        final alignments = <int, pw.Alignment>{
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.centerLeft,
        };
        int colIdx = 4;
        for (var _ in sortedProducts) {
          alignments[colIdx++] = pw.Alignment.center;
        }
        alignments[colIdx++] = pw.Alignment.centerRight; // Subtotal
        alignments[colIdx++] = pw.Alignment.center;      // GST Rate
        alignments[colIdx++] = pw.Alignment.centerRight; // GST Amt
        alignments[colIdx++] = pw.Alignment.centerRight; // Total
        alignments[colIdx++] = pw.Alignment.centerRight; // Paid
        alignments[colIdx++] = pw.Alignment.centerRight; // Balance
        alignments[colIdx++] = pw.Alignment.center;      // Status
        return alignments;
      } else if (_reportType == 'distributor') {
        return {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.center,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        };
      } else {
        return {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.center,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        };
      }
    }

    Map<int, pw.TableColumnWidth>? _buildPdfColumnWidths() {
      if (_reportType == 'expense') {
        return {
          0: const pw.FlexColumnWidth(1.5),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(3),
          3: const pw.FlexColumnWidth(1.5),
        };
      } else if (_reportType == 'order_wise') {
        final widths = <int, pw.TableColumnWidth>{
          0: const pw.FlexColumnWidth(1.2), // Invoice No
          1: const pw.FlexColumnWidth(1.2), // Date
          2: const pw.FlexColumnWidth(2.5), // Customer Name
          3: const pw.FlexColumnWidth(1.8), // GST Number
        };
        int colIdx = 4;
        for (var _ in sortedProducts) {
          widths[colIdx++] = const pw.FlexColumnWidth(4.5); // Product columns
        }
        widths[colIdx++] = const pw.FlexColumnWidth(1.2); // Subtotal
        widths[colIdx++] = const pw.FlexColumnWidth(0.9); // GST Rate
        widths[colIdx++] = const pw.FlexColumnWidth(1.1); // GST Amt
        widths[colIdx++] = const pw.FlexColumnWidth(1.2); // Total
        widths[colIdx++] = const pw.FlexColumnWidth(1.2); // Paid
        widths[colIdx++] = const pw.FlexColumnWidth(1.2); // Balance
        widths[colIdx++] = const pw.FlexColumnWidth(1.1); // Status
        return widths;
      } else if (_reportType == 'distributor') {
        return {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(1.5),
          4: const pw.FlexColumnWidth(1.5),
          5: const pw.FlexColumnWidth(1.5),
        };
      } else {
        return {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(1.5),
          4: const pw.FlexColumnWidth(1.5),
        };
      }
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return [
            // Header
            pw.Text('BUSINESS REPORT: ${_getReportTypeName()}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Period: ${_getDateRangeDescription()}'),
            pw.SizedBox(height: 10),
        
            // Data Table
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, 
                fontSize: _reportType == 'order_wise' ? 6 : 8, 
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: pw.TextStyle(fontSize: _reportType == 'order_wise' ? 6 : 8),
              cellPadding: _reportType == 'order_wise' 
                  ? const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3)
                  : const pw.EdgeInsets.all(4),
              headers: _reportType == 'expense' 
                  ? ['Date', 'Type', 'Description', 'Amount']
                  : _reportType == 'order_wise'
                      ? [
                          'Invoice No',
                          'Date',
                          'Customer/Shop Name',
                          'GST Number',
                          ...sortedProducts,
                          'Subtotal',
                          'GST Rate',
                          'GST Amt',
                          'Total',
                          'Paid',
                          'Balance',
                          'Status'
                        ]
                      : _reportType == 'distributor'
                          ? ['Distributor Name', 'Orders', 'Sales', 'Comm.', 'Paid', 'Bal']
                          : ['Entity Name', 'Orders', 'Total Sales', 'Total Paid', 'Balance'],
              data: _buildPdfDataRows(data),
              columnWidths: _buildPdfColumnWidths(),
              cellAlignments: _buildPdfCellAlignments(),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Business_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }

  Future<void> _exportCleanCustomerDirectory(BuildContext context) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('customers').get();
      List<List<dynamic>> rows = [
        ['Shop/Customer Name', 'Mobile Number', 'Address', 'GST Number', 'Total Orders', 'Total Sales']
      ];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        rows.add([
          data['shopName'] ?? '',
          data['mobileNumber'] ?? '',
          data['address'] ?? '',
          data['gstNumber'] ?? '',
          data['totalOrders'] ?? 0,
          (data['totalAmountSpent'] ?? 0.0).toStringAsFixed(2),
        ]);
      }
      
      String csvData = Csv().encode(rows);
      final bytes = utf8.encode(csvData);
      final fileName = 'Customer_Directory_${DateTime.now().millisecondsSinceEpoch}.csv';
      
      await downloadFile(bytes, fileName, mimeType: 'text/csv');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer Directory Exported')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final bool isAccountant = authState is Authenticated && authState.user.role == 'accountant';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Advanced Business Reports'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: BlocBuilder<ExpenseBloc, ExpenseState>(
        builder: (context, expenseState) {
          return BlocBuilder<OrderBloc, OrderState>(
            builder: (context, state) {
              if (state is OrderLoading || expenseState is ExpenseLoading) return const Center(child: CircularProgressIndicator());
              if (state is OrdersLoaded && expenseState is ExpensesLoaded) {
                final loadedState = state as OrdersLoaded;
                final data = _processData(loadedState.orders);
                
                // Calculations for generic UI
                double totalSales = data.fold(0.0, (sum, row) => sum + (row['sales'] as double));
                int totalOrders = data.fold(0, (sum, row) => sum + (row['orders'] as int));
                
                // Expense specific data processing for UI
                var expenses = _processExpenses(expenseState.expenses);
                double totalExpenses = expenses.fold(0.0, (sum, exp) => sum + exp.amount);

                return Column(
                  children: [
                // Filters Section
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _reportType,
                              decoration: InputDecoration(
                                labelText: 'Report Type',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem(value: 'all', child: Text('All Orders (Summary)', overflow: TextOverflow.ellipsis)),
                                const DropdownMenuItem(value: 'order_wise', child: Text('Order-wise (GST)', overflow: TextOverflow.ellipsis)),
                                if (!isAccountant) ...[
                                  const DropdownMenuItem(value: 'partner', child: Text('Partner-wise', overflow: TextOverflow.ellipsis)),
                                  const DropdownMenuItem(value: 'distributor', child: Text('Distributor-wise', overflow: TextOverflow.ellipsis)),
                                  const DropdownMenuItem(value: 'customer', child: Text('Customer-wise', overflow: TextOverflow.ellipsis)),
                                ],
                                const DropdownMenuItem(value: 'expense', child: Text('Expense Report', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (val) => _onReportTypeChanged(val!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month),
                              label: Text(_dateRange == null 
                                ? 'Select Dates' 
                                : '${DateFormat('dd/MM/yy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yy').format(_dateRange!.end)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _selectDateRange(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _sortOrder,
                                icon: const Icon(Icons.sort, size: 16, color: Color(0xFF1E3A8A)),
                                style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 12),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _sortOrder = newValue;
                                    });
                                  }
                                },
                                items: _getSortItems(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  FilterChip(
                                    label: const Text('All Time', style: TextStyle(fontSize: 12)),
                                    selected: _periodFilter == 'All',
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _periodFilter = 'All';
                                          _dateRange = null;
                                        });
                                      }
                                    },
                                    selectedColor: const Color(0xFFEFF6FF),
                                    checkmarkColor: const Color(0xFF1E3A8A),
                                    labelStyle: TextStyle(
                                      color: _periodFilter == 'All' ? const Color(0xFF1E3A8A) : Colors.grey.shade600,
                                      fontWeight: _periodFilter == 'All' ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    side: BorderSide(
                                      color: _periodFilter == 'All' ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : Colors.grey.shade300,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  FilterChip(
                                    label: const Text('Daily', style: TextStyle(fontSize: 12)),
                                    selected: _periodFilter == 'Daily',
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _periodFilter = 'Daily';
                                          _dateRange = null;
                                        });
                                      }
                                    },
                                    selectedColor: const Color(0xFFEFF6FF),
                                    checkmarkColor: const Color(0xFF1E3A8A),
                                    labelStyle: TextStyle(
                                      color: _periodFilter == 'Daily' ? const Color(0xFF1E3A8A) : Colors.grey.shade600,
                                      fontWeight: _periodFilter == 'Daily' ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    side: BorderSide(
                                      color: _periodFilter == 'Daily' ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : Colors.grey.shade300,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  FilterChip(
                                    label: const Text('Monthly', style: TextStyle(fontSize: 12)),
                                    selected: _periodFilter == 'Monthly',
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _periodFilter = 'Monthly';
                                          _dateRange = null;
                                        });
                                      }
                                    },
                                    selectedColor: const Color(0xFFEFF6FF),
                                    checkmarkColor: const Color(0xFF1E3A8A),
                                    labelStyle: TextStyle(
                                      color: _periodFilter == 'Monthly' ? const Color(0xFF1E3A8A) : Colors.grey.shade600,
                                      fontWeight: _periodFilter == 'Monthly' ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    side: BorderSide(
                                      color: _periodFilter == 'Monthly' ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : Colors.grey.shade300,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  FilterChip(
                                    label: const Text('Financial Year', style: TextStyle(fontSize: 12)),
                                    selected: _periodFilter == 'Financial Year',
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _periodFilter = 'Financial Year';
                                          _dateRange = null;
                                        });
                                      }
                                    },
                                    selectedColor: const Color(0xFFEFF6FF),
                                    checkmarkColor: const Color(0xFF1E3A8A),
                                    labelStyle: TextStyle(
                                      color: _periodFilter == 'Financial Year' ? const Color(0xFF1E3A8A) : Colors.grey.shade600,
                                      fontWeight: _periodFilter == 'Financial Year' ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    side: BorderSide(
                                      color: _periodFilter == 'Financial Year' ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_reportType != 'all' || _dateRange != null || _periodFilter != 'All' || _sortOrder != 'Desc' || _reportType == 'customer') ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_reportType == 'customer')
                              TextButton.icon(
                                icon: const Icon(Icons.people_outline, color: Color(0xFF1E3A8A)),
                                label: const Text('Download Customer List', style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
                                onPressed: () => _exportCleanCustomerDirectory(context),
                              )
                            else
                              const SizedBox(),
                            if (_reportType != 'all' || _dateRange != null || _periodFilter != 'All' || _sortOrder != 'Desc')
                              TextButton.icon(
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Clear Filters'),
                                onPressed: _clearFilters,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Summary Cards
                if (_reportType == 'expense')
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFEF4444)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Expenses', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                Text('₹${totalExpenses.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Entries', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                Text('${expenses.length}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Sales', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                Text('₹${totalSales.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)]),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Orders', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                Text('$totalOrders', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Data List
                Expanded(
                  child: _reportType == 'expense'
                    ? expenses.isEmpty
                        ? const Center(child: Text('No expenses found for selected filters.'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: expenses.length,
                            itemBuilder: (context, index) {
                              final exp = expenses[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  title: Text(exp.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('Date: ${DateFormat('dd MMM yyyy').format(exp.date)}'),
                                      if (exp.description != null && exp.description!.isNotEmpty)
                                        Text('Desc: ${exp.description}', style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                  trailing: Text(
                                    '₹${exp.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              );
                            },
                          )
                    : data.isEmpty 
                        ? const Center(child: Text('No data found for selected filters.'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: data.length,
                            itemBuilder: (context, index) {
                              final row = data[index];
                              final double sales = row['sales'];
                              final double paid = row['paid'];
                              final double balance = sales - paid;
                              final bool isOrderWise = row['isOrderWise'] ?? false;

                            if (isOrderWise) {
                              final String invoiceNo = row['invoiceNumber'] ?? 'N/A';
                              final String date = row['date'] ?? '';
                              final String paymentStatus = row['paymentStatus'] ?? 'Pending';
                              final double subtotal = row['subtotal'] ?? 0.0;
                              final double gstAmount = row['gstAmount'] ?? 0.0;
                              final String customerGst = row['customerGst'] ?? 'N/A';

                              Color statusColor = Colors.red;
                              if (paymentStatus == 'Paid') statusColor = Colors.green;
                              else if (paymentStatus == 'Partial') statusColor = Colors.orange;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade100),
                                    color: Colors.white,
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  row['name'] ?? '',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A8A)),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Invoice: $invoiceNo | Date: $date',
                                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              paymentStatus.toUpperCase(),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildStatColumn('Subtotal', subtotal, Colors.black87),
                                          _buildStatColumn('GST (5%)', gstAmount, Colors.black87),
                                          _buildStatColumn('Total', sales, const Color(0xFF1E3A8A)),
                                          _buildStatColumn('Paid', paid, Colors.green),
                                          _buildStatColumn('Balance', balance, balance > 0 ? Colors.red : Colors.grey),
                                        ],
                                      ),
                                      if (customerGst != 'N/A' && customerGst.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(Icons.description_outlined, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Customer GSTIN: $customerGst',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              row['crateDetails'] ?? '',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return Card(
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
                                        Expanded(child: Text(row['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                                          child: Text('${row['orders']} Orders', style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildStatColumn('Sales', sales, Colors.black87),
                                        if (_reportType == 'distributor')
                                          _buildStatColumn('Commission', row['commission'] ?? 0.0, Colors.indigo),
                                        _buildStatColumn('Paid', paid, Colors.green),
                                        _buildStatColumn('Balance', balance, balance > 0 ? Colors.red : Colors.grey),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Action Buttons
                if (_reportType == 'expense' || data.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.black12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.table_chart),
                            label: const Text('Export CSV'),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                            onPressed: () => _exportCsv(data),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Export PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () => _exportPdf(data, totalSales),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }
          return const Center(child: Text('Error loading orders.'));
        },
      );
    },
  ),
);
  }

  Widget _buildStatColumn(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text('₹${value.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }
}
