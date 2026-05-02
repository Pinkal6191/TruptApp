import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/order_item_model.dart';

class InvoiceService {
  static Future<void> generateAndShareInvoice(OrderModel order) async {
    final pdf = pw.Document();

    // Use a default font or load one if needed. Using default for simplicity.
    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    final String upiId = 'business@upi'; // Replace with real UPI ID
    final String payeeName = 'Trupt Enterprise';
    // Generate UPI URI
    final String upiUri = 'upi://pay?pa=$upiId&pn=$payeeName&am=${order.finalAmount.toStringAsFixed(2)}&cu=INR';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TRUPT ENTERPRISE', style: pw.TextStyle(font: boldFont, fontSize: 24, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text('Wholesale Water Distributors', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)),
                      pw.Text('123 Enterprise Way, City, State 12345', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
                      pw.Text('Phone: +91 98765 43210', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('INVOICE', style: pw.TextStyle(font: boldFont, fontSize: 28, color: PdfColors.blue800)),
                      pw.SizedBox(height: 4),
                      pw.Text('Date: ${DateFormat('dd MMM yyyy').format(order.createdAt)}', style: pw.TextStyle(font: font)),
                      pw.Text('Order ID: ${order.id.isEmpty ? 'PENDING' : order.id.substring(0, 8).toUpperCase()}', style: pw.TextStyle(font: font)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              // Billed To
              pw.Text('Billed To:', style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.SizedBox(height: 4),
              pw.Text('Partner: ${order.partnerName}', style: pw.TextStyle(font: font, fontSize: 12)),
              pw.SizedBox(height: 24),

              // Items Table
              _buildItemsTable(order.items, font, boldFont),
              pw.SizedBox(height: 24),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        _buildTotalRow('Subtotal:', order.subtotal, font),
                        pw.SizedBox(height: 4),
                        _buildTotalRow('GST (18%):', order.gstAmount, font),
                        pw.Divider(),
                        _buildTotalRow('Total Amount:', order.finalAmount, boldFont, isTotal: true),
                        pw.SizedBox(height: 8),
                        _buildTotalRow('Amount Paid:', order.paidAmount, font, color: PdfColors.green700),
                        pw.SizedBox(height: 4),
                        _buildTotalRow('Balance Due:', order.finalAmount - order.paidAmount, boldFont, color: PdfColors.red700),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 40),

              // Footer with QR Code
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Terms & Conditions:', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                      pw.Text('1. Payment is due upon receipt.', style: pw.TextStyle(font: font, fontSize: 8)),
                      pw.Text('2. Please make checks payable to Trupt Enterprise.', style: pw.TextStyle(font: font, fontSize: 8)),
                      pw.SizedBox(height: 16),
                      pw.Text('Thank you for your business!', style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColors.blue900)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Scan to Pay via UPI', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        height: 80,
                        width: 80,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: upiUri,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(upiId, style: pw.TextStyle(font: font, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Share the PDF
    final Uint8List bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Invoice_${order.partnerName}_${DateFormat('ddMMM').format(order.createdAt)}.pdf');
  }

  static pw.Widget _buildItemsTable(List<OrderItemModel> items, pw.Font font, pw.Font boldFont) {
    return pw.TableHelper.fromTextArray(
      headers: ['Item Description', 'Qty', 'Unit Price', 'Amount'],
      data: items.map((item) => [
        item.productName,
        item.quantity.toString(),
        'Rs. ${item.unitPrice.toStringAsFixed(2)}',
        'Rs. ${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
      ]).toList(),
      headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: pw.TextStyle(font: font),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  static pw.Widget _buildTotalRow(String label, double value, pw.Font font, {bool isTotal = false, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: isTotal ? 14 : 12,
          ),
        ),
        pw.Text(
          'Rs. ${value.toStringAsFixed(2)}',
          style: pw.TextStyle(
            font: font,
            fontSize: isTotal ? 14 : 12,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }
}
