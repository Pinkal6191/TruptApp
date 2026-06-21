import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/order_item_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceService {
  static Future<void> generateAndShareInvoice(OrderModel order, {bool withGst = true}) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    // Try to load QR image
    pw.MemoryImage? qrImage;
    try {
      final qrData = await rootBundle.load('assets/images/payment_qr.png');
      qrImage = pw.MemoryImage(qrData.buffer.asUint8List());
    } catch (e) {
      print('QR code not found: $e');
    }

    // Fix for old bills that didn't save subtotal and gstAmount
    double printSubtotal = order.subtotal;
    double printGst = order.gstAmount;
    if (printSubtotal == 0 && order.finalAmount > 0) {
      printSubtotal = order.finalAmount / 1.05;
      printGst = order.finalAmount - printSubtotal;
    }

    // Invoice number formatting: ddmmyyyyhhmmss fallback for old orders
    String invNo = order.invoiceNumber;
    if (invNo.isEmpty) {
      invNo = DateFormat('ddMMyyyyHHmmss').format(order.createdAt);
    }

    String customerGst = order.customerGstNumber;
    if (customerGst.trim().isEmpty || customerGst.trim() == 'URP') {
      try {
        final query = await FirebaseFirestore.instance
            .collection('customers')
            .where('mobileNumber', isEqualTo: order.customerMobile)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final gst = query.docs.first.data()['gstNumber'] as String?;
          if (gst != null && gst.trim().isNotEmpty) {
            customerGst = gst.trim();
          }
        }
      } catch (e) {
        print("Failed to fetch customer GST: $e");
      }
    }

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
                      pw.Text('Trupt Enterprise, 4160, B/H Mahalaxmi Cold Storage,', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Boriavi, Anand-387310', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Phone: +91 96624 98664, +91 98793 95727', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Email: truptenterprise26@gmail.com', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Website: truptenterprise.com', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('GST: 24AAZFT5241K1ZK', style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.black)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(withGst ? 'TAX INVOICE' : 'INVOICE', style: pw.TextStyle(font: boldFont, fontSize: 28, color: PdfColors.blue800)),
                      pw.SizedBox(height: 4),
                      pw.Text('Date: ${DateFormat('dd MMM yyyy').format(order.createdAt)}', style: pw.TextStyle(font: font)),
                      pw.Text('Invoice No: $invNo', style: pw.TextStyle(font: font)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              // Billed To
              pw.Text('Billed To:', style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.SizedBox(height: 4),
              pw.Text('Shop/Customer: ${order.shopName.isEmpty ? order.partnerName : order.shopName}', style: pw.TextStyle(font: boldFont, fontSize: 12)),
              if (order.customerAddress.isNotEmpty)
                pw.Text('Address: ${order.customerAddress}', style: pw.TextStyle(font: font, fontSize: 10)),
              pw.Text('Contact: ${order.customerMobile}', style: pw.TextStyle(font: font, fontSize: 10)),
              if (customerGst.isNotEmpty && customerGst != 'URP')
                pw.Text('GST No: $customerGst', style: pw.TextStyle(font: font, fontSize: 10)),
              pw.SizedBox(height: 24),

              // Items Table
              _buildItemsTable(order.items, font, boldFont, withGst: withGst),
              pw.SizedBox(height: 24),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        if (withGst) ...[
                          _buildTotalRow('Taxable Value:', printSubtotal, font),
                          pw.SizedBox(height: 4),
                          _buildTotalRow('SGST (2.5%):', printGst / 2, font),
                          pw.SizedBox(height: 4),
                          _buildTotalRow('CGST (2.5%):', printGst / 2, font),
                          pw.Divider(),
                        ],
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
              
              // Spacer to push footer to bottom if needed, but the original layout didn't have one.
              pw.Spacer(),

              // Footer with Bank Details & QR Code
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bank Detail :', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                      pw.SizedBox(height: 4),
                      pw.Text('Bank : AU Small Finance Bank', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('A/c. No.2701202627012026', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('IFSC Code : AUBL0004102', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('UPI ID : truptenterprise2644@aubank', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.SizedBox(height: 16),
                      pw.Text('Terms & Conditions:', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                      pw.Text('1. Payment is due upon receipt.', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('2. All disputes are subject to local jurisdiction.', style: pw.TextStyle(font: font, fontSize: 10)),
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
                        child: qrImage != null 
                          ? pw.Image(qrImage)
                          : pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: 'upi://pay?pa=truptenterprise2644@aubank&pn=Trupt%20Enterprise',
                              color: PdfColors.black,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Center(
                child: pw.Text('Subject to Anand Jurisdiction', style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColors.blue900)),
              ),
            ],
          );
        },
      ),
    );

    // Share the PDF
    final Uint8List bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Invoice_${order.shopName.isEmpty ? order.partnerName : order.shopName}_$invNo.pdf');
  }

  static pw.Widget _buildItemsTable(List<OrderItemModel> items, pw.Font font, pw.Font boldFont, {bool withGst = true}) {
    return pw.TableHelper.fromTextArray(
      headers: withGst 
          ? ['Item Description', 'Qty (Crates)', 'Rate/Crate', 'Total Price', 'GST (5% Incl.)', 'Taxable Value']
          : ['Item Description', 'Qty (Crates)', 'Rate/Crate', 'Total Price'],
      data: items.map((item) {
        final double gross = item.quantity * item.pricePerCrate;
        if (withGst) {
          final double taxable = gross / 1.05;
          final double gst = gross - taxable;
          return [
            item.productName,
            '${item.quantity} caret',
            'Rs. ${item.pricePerCrate.toStringAsFixed(2)}',
            'Rs. ${gross.toStringAsFixed(2)}',
            'Rs. ${gst.toStringAsFixed(2)}',
            'Rs. ${taxable.toStringAsFixed(2)}',
          ];
        } else {
          return [
            item.productName,
            '${item.quantity} caret',
            'Rs. ${item.pricePerCrate.toStringAsFixed(2)}',
            'Rs. ${gross.toStringAsFixed(2)}',
          ];
        }
      }).toList(),
      headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: pw.TextStyle(font: font, fontSize: 8),
      cellAlignments: withGst 
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
