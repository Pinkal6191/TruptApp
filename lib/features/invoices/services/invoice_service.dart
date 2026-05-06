import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/order_item_model.dart';

class InvoiceService {
  static Future<void> generateAndShareInvoice(OrderModel order, {bool withGst = true}) async {
    final pdf = pw.Document();

    pw.MemoryImage? qrImage;

    try {
      final qrData = await rootBundle.load('assets/images/payment_qr.png');
      qrImage = pw.MemoryImage(qrData.buffer.asUint8List());
    } catch (e) {
      print('QR code not found: $e');
    }

    // Colors matching the sample
    final darkGrey = PdfColor.fromHex('#4B5563');
    final blueColor = PdfColor.fromHex('#3B82F6'); 
    final lightGrey = PdfColor.fromHex('#E5E7EB');
    final tableBorderColor = PdfColor.fromHex('#3B82F6'); // The table borders in the sample are blue

    // Fix for old bills that didn't save subtotal and gstAmount
    double printSubtotal = order.subtotal;
    double printGst = order.gstAmount;
    if (printSubtotal == 0 && order.finalAmount > 0) {
      printSubtotal = order.finalAmount / 1.05;
      printGst = order.finalAmount - printSubtotal;
    }

    // Use last 6 characters of order ID as Invoice Number if empty
    final String invNo = order.id.isEmpty ? '1' : order.id.substring(order.id.length - 6).toUpperCase();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section (Dark Grey Background)
              pw.Container(
                color: darkGrey,
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Logo and Brand Name
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.RichText(
                          text: pw.TextSpan(
                            children: [
                              pw.TextSpan(text: 'Tr', style: pw.TextStyle(color: PdfColors.blue300, fontSize: 32, fontWeight: pw.FontWeight.bold)),
                              pw.TextSpan(text: 'upt', style: pw.TextStyle(color: PdfColors.white, fontSize: 32, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text('Har Boond Mein Trupti', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                        pw.SizedBox(height: 6),
                        pw.Text('Trupt Enterprise, 4160, B/H Mahalaxmi Cold Storage, Boriavi, Anand-387310', 
                          style: pw.TextStyle(color: PdfColors.grey300, fontSize: 7)),
                      ],
                    ),
                    // Contact Info
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('+91 96624 98664, +91 98793 95727', style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                        pw.SizedBox(height: 2),
                        pw.Text('truptenterprise.com', style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                        pw.SizedBox(height: 2),
                        pw.Text('truptenterprise26@gmail.com', style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),

              // GST Bar
              pw.Container(
                color: lightGrey,
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Center(
                  child: pw.Text('GST No. 24AAZFT5241K1ZK', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ),
              ),
              pw.SizedBox(height: 16),

              // Invoice Details & Customer Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'Invoice No :  ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.TextSpan(text: invNo, style: const pw.TextStyle(color: PdfColors.red, fontSize: 11)),
                      ],
                    ),
                  ),
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(text: 'Date : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.TextSpan(text: DateFormat('dd/MM/yyyy').format(order.createdAt), style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Customer Name   ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.TextSpan(text: order.shopName.isEmpty ? order.partnerName : order.shopName, style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(text: 'Address               ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.TextSpan(text: 'Mobile: ${order.customerMobile}', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Table
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: blueColor, width: 1),
                headerDecoration: pw.BoxDecoration(color: blueColor),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 11),
                cellAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                  5: const pw.FlexColumnWidth(2), // Empty header for Amount
                },
                headers: ['Sr.No.', 'Product Name', 'No.of Bottles', 'No.of Crates', 'Rate', ''],
                data: List<List<String>>.generate(
                  order.items.length,
                  (index) {
                    final item = order.items[index];
                    final amount = item.quantity * item.pricePerCrate;
                    return [
                      '${index + 1}',
                      item.productName,
                      '', // Blank in sample
                      '${item.quantity}',
                      item.pricePerCrate.toStringAsFixed(0),
                      amount.toStringAsFixed(0),
                    ];
                  },
                ),
              ),
              
              // Big empty space block with blue side borders to match the sample design
              pw.Expanded(
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      left: pw.BorderSide(color: blueColor, width: 1),
                      right: pw.BorderSide(color: blueColor, width: 1),
                      bottom: pw.BorderSide(color: blueColor, width: 1),
                    )
                  ),
                  child: pw.Center(
                    child: pw.Opacity(
                      opacity: 0.1,
                      child: pw.Text('Trupt', style: pw.TextStyle(fontSize: 80, fontWeight: pw.FontWeight.bold, color: blueColor))
                    )
                  )
                )
              ),

              // Footer Section (Bank Details & Totals)
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Bank Details Box
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: blueColor, width: 1),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            width: double.infinity,
                            color: blueColor,
                            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: pw.Text('Bank Details', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Expanded(
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('Bank : AU Small Finance Bank', style: const pw.TextStyle(fontSize: 10)),
                                      pw.Text('A/c. No.270120262712026', style: const pw.TextStyle(fontSize: 10)),
                                      pw.Text('IFSC Code : AUBL0004101', style: const pw.TextStyle(fontSize: 10)),
                                      pw.Text('UPI ID : truptenterprise2644@aubank', style: const pw.TextStyle(fontSize: 10)),
                                    ],
                                  ),
                                ),
                                if (qrImage != null)
                                  pw.Container(
                                    width: 60,
                                    height: 60,
                                    child: pw.Image(qrImage),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Totals Box
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(
                          top: pw.BorderSide(color: blueColor, width: 1),
                          right: pw.BorderSide(color: blueColor, width: 1),
                          bottom: pw.BorderSide(color: blueColor, width: 1),
                        ),
                      ),
                      child: pw.Column(
                        children: [
                          if (withGst) ...[
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: blueColor))),
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('Subtotal ₹', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                                  pw.Text(printSubtotal.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: blueColor))),
                              child: pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('GST', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                                  pw.Text(printGst.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Final Total: ₹', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                                pw.Text('${order.finalAmount.toStringAsFixed(0)}/-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Bottom Strip
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8),
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: blueColor,
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subject to Anand Jurisdiction', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Column(
                      children: [
                         pw.Text('Signature', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                      ]
                    )
                  ],
                ),
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
}
