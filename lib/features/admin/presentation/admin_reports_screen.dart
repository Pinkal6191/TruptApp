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
import '../../../core/utils/file_downloader.dart';
import '../../../core/utils/route_tracker.dart';
import '../../orders/bloc/order_bloc.dart';
import '../../orders/bloc/order_event.dart';
import '../../orders/bloc/order_state.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String _reportType = 'all'; // all, partner, distributor, customer
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    RouteTracker.saveRoute('admin_reports');
    context.read<OrderBloc>().add(LoadAllOrders());
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
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _reportType = 'all';
      _dateRange = null;
    });
  }

  List<Map<String, dynamic>> _processData(List<OrderModel> orders) {
    List<OrderModel> filtered = orders;

    if (_dateRange != null) {
      filtered = filtered.where((o) {
        final date = DateTime(o.createdAt.year, o.createdAt.month, o.createdAt.day);
        final start = DateTime(_dateRange!.start.year, _dateRange!.start.month, _dateRange!.start.day);
        final end = DateTime(_dateRange!.end.year, _dateRange!.end.month, _dateRange!.end.day);
        return date.isAtSameMomentAs(start) || date.isAtSameMomentAs(end) || (date.isAfter(start) && date.isBefore(end));
      }).toList();
    }

    if (_reportType == 'partner') {
      filtered = filtered.where((o) =>
        o.creatorRole == 'partner' ||
        (o.creatorRole == 'admin' && o.orderReference != 'Direct (Online / Call)')
      ).toList();
    } else if (_reportType == 'distributor') {
      filtered = filtered.where((o) => o.creatorRole == 'distributor').toList();
    }

    if (_reportType == 'order_wise') {
      List<OrderModel> sorted = List.from(filtered);
      sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return sorted.map((o) => {
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
        'isOrderWise': true,
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
      if (o.creatorRole == 'distributor') {
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
    resultList.sort((a, b) => (b['sales'] as double).compareTo(a['sales'] as double));
    return resultList;
  }

  String _getDateRangeDescription() {
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
      case 'order_wise':
        return 'Order-wise (GST Detailed)';
      case 'partner':
        return 'Partner-wise Summary';
      case 'distributor':
        return 'Distributor-wise Summary';
      case 'customer':
        return 'Customer-wise Summary';
      case 'all':
      default:
        return 'All Orders Summary';
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
      rows.add([
        'Invoice No',
        'Date',
        'Customer/Shop Name',
        'GST Number',
        'Subtotal (Excl. GST)',
        'GST Rate',
        'GST Amount',
        'Total (Incl. GST)',
        'Paid Amount',
        'Balance Amount',
        'Payment Status'
      ]);

      for (var row in data) {
        double subtotal = row['subtotal'] ?? 0.0;
        double gstAmount = row['gstAmount'] ?? 0.0;
        double sales = row['sales'] ?? 0.0;
        double paid = row['paid'] ?? 0.0;
        double balance = sales - paid;

        rows.add([
          row['invoiceNumber'] ?? '',
          row['date'] ?? '',
          row['name'] ?? '',
          row['customerGst'] ?? '',
          subtotal.toStringAsFixed(2),
          '5%',
          gstAmount.toStringAsFixed(2),
          sales.toStringAsFixed(2),
          paid.toStringAsFixed(2),
          balance.toStringAsFixed(2),
          row['paymentStatus'] ?? ''
        ]);
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
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return [
            // Company and Report Header Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left: Company Info
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TRUPT ENTERPRISE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.SizedBox(height: 4),
                    pw.Text('4160, B/H Mahalaxmi Cold Storage, Boriavi, Anand - 387310', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Phone: +91 96624 98664, +91 98793 95727', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text('Email: truptenterprise26@gmail.com | Website: truptenterprise.com', style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 2),
                    pw.Text('GSTIN: 24AAZFT5241K1ZK', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                  ],
                ),
                // Right: Report Details
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('BUSINESS REPORT', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.SizedBox(height: 4),
                    pw.Text('Report Type: ${_getReportTypeName()}', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(_getDateRangeDescription(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.Text('Generated On: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // Summary metrics
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Sales: Rs. ${totalSales.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text('Total Records: ${data.length}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
              ],
            ),
            pw.SizedBox(height: 12),

            // Main Table
            pw.TableHelper.fromTextArray(
              headers: _reportType == 'order_wise'
                  ? ['Inv No', 'Date', 'Customer/Shop', 'GST Number', 'Subtotal', 'GST (5%)', 'Total', 'Paid', 'Balance']
                  : _reportType == 'distributor'
                      ? ['Name', 'Orders', 'Total Sales', 'Commission', 'Total Paid', 'Balance']
                      : ['Name', 'Orders', 'Total Sales', 'Total Paid', 'Balance'],
              data: data.map((row) {
                if (_reportType == 'order_wise') {
                  final double subtotal = row['subtotal'] ?? 0.0;
                  final double gstAmount = row['gstAmount'] ?? 0.0;
                  final double sales = row['sales'] ?? 0.0;
                  final double paid = row['paid'] ?? 0.0;
                  final double balance = sales - paid;
                  return [
                    row['invoiceNumber'] ?? '',
                    row['date'] ?? '',
                    row['name'] ?? '',
                    row['customerGst'] ?? 'N/A',
                    'Rs. ${subtotal.toStringAsFixed(2)}',
                    'Rs. ${gstAmount.toStringAsFixed(2)}',
                    'Rs. ${sales.toStringAsFixed(2)}',
                    'Rs. ${paid.toStringAsFixed(2)}',
                    'Rs. ${balance.toStringAsFixed(2)}',
                  ];
                } else if (_reportType == 'distributor') {
                  return [
                    row['name'],
                    row['orders'].toString(),
                    'Rs. ${(row['sales'] as double).toStringAsFixed(2)}',
                    'Rs. ${(row['commission'] as double? ?? 0.0).toStringAsFixed(2)}',
                    'Rs. ${(row['paid'] as double).toStringAsFixed(2)}',
                    'Rs. ${((row['sales'] as double) - (row['paid'] as double)).toStringAsFixed(2)}',
                  ];
                } else {
                  return [
                    row['name'],
                    row['orders'].toString(),
                    'Rs. ${(row['sales'] as double).toStringAsFixed(2)}',
                    'Rs. ${(row['paid'] as double).toStringAsFixed(2)}',
                    'Rs. ${((row['sales'] as double) - (row['paid'] as double)).toStringAsFixed(2)}',
                  ];
                }
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignments: _reportType == 'order_wise'
                  ? {
                      0: pw.Alignment.centerLeft,
                      1: pw.Alignment.center,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.center,
                      4: pw.Alignment.centerRight,
                      5: pw.Alignment.centerRight,
                      6: pw.Alignment.centerRight,
                      7: pw.Alignment.centerRight,
                      8: pw.Alignment.centerRight,
                    }
                  : _reportType == 'distributor'
                      ? {
                          0: pw.Alignment.centerLeft,
                          1: pw.Alignment.center,
                          2: pw.Alignment.centerRight,
                          3: pw.Alignment.centerRight,
                          4: pw.Alignment.centerRight,
                          5: pw.Alignment.centerRight,
                        }
                      : {
                          0: pw.Alignment.centerLeft,
                          1: pw.Alignment.center,
                          2: pw.Alignment.centerRight,
                          3: pw.Alignment.centerRight,
                          4: pw.Alignment.centerRight,
                        },
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Advanced Business Reports'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: BlocBuilder<OrderBloc, OrderState>(
        builder: (context, state) {
          if (state is OrderLoading) return const Center(child: CircularProgressIndicator());
          if (state is OrdersLoaded) {
            final loadedState = state as OrdersLoaded;
            final data = _processData(loadedState.orders);
            double totalSales = data.fold(0.0, (sum, row) => sum + (row['sales'] as double));
            int totalOrders = data.fold(0, (sum, row) => sum + (row['orders'] as int));

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
                              value: _reportType,
                              decoration: InputDecoration(
                                labelText: 'Report Type',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('All Orders (Summary)')),
                                DropdownMenuItem(value: 'order_wise', child: Text('Order-wise (GST Detailed)')),
                                DropdownMenuItem(value: 'partner', child: Text('Partner-wise')),
                                DropdownMenuItem(value: 'distributor', child: Text('Distributor-wise')),
                                DropdownMenuItem(value: 'customer', child: Text('Customer-wise')),
                              ],
                              onChanged: (val) => setState(() => _reportType = val!),
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
                      if (_reportType != 'all' || _dateRange != null || _reportType == 'customer') ...[
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
                            if (_reportType != 'all' || _dateRange != null)
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
                  child: data.isEmpty 
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
                if (data.isNotEmpty)
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
          return const SizedBox();
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
