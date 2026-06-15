import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../data/purchase_order_model.dart';
import 'package:flutter/services.dart';

class PurchaseOrderPdfService {
  static Future<Uint8List> generatePdf(PurchaseOrderModel po) async {
    final pdf = pw.Document();

    // Try loading a logo from assets if it exists, otherwise fallback to text
    pw.MemoryImage? logoImage;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      // ignore
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        height: 50,
                        child: pw.Image(logoImage),
                      )
                    else
                      pw.Text(
                        'TRUPT ENTERPRISE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    pw.SizedBox(height: 8),
                    pw.Text('4160, B/H Mahalaxmi Cold Storage,', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Boriavi, Anand - 387310, Gujarat, India', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Phone: +91 96624 98664 / +91 98793 95727', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Email: truptenterprise26@gmail.com', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('GSTIN: 24AAZFT5241K1ZK', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'PURCHASE ORDER',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Date: ${DateFormat('dd/MM/yyyy').format(po.createdAt)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('PO Number: ${po.poNumber}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 20),

            // Vendor Info
            pw.Text('To,', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(po.vendorName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text(po.vendorAddress, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 12),
            pw.Text('Kind attention: ${po.attentionName}', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Contact no.: ${po.contactNumber}', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 20),

            // Subject
            pw.Text('Sub: Purchase Order no. ${po.poNumber}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('Dear Sir/Madam,', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 8),
            pw.Text('We hereby order to supply the following material/services:', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 16),

            // Data Table
            pw.TableHelper.fromTextArray(
              headers: ['SR NO', 'PART NUMBER', 'DESCRIPTION', 'UOM', 'SPECIAL PRICE', 'QUANTITY', 'HSN/SAC', 'IGST RATE'],
              data: po.items.asMap().entries.map((entry) {
                int idx = entry.key + 1;
                PurchaseOrderItemModel item = entry.value;
                return [
                  idx.toString(),
                  item.partNumber,
                  item.description,
                  item.uom,
                  item.specialPrice.toStringAsFixed(2),
                  item.quantity.toStringAsFixed(2),
                  item.hsnCode,
                  '${item.igstRate.toStringAsFixed(2)}%',
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.center,
                7: pw.Alignment.centerRight,
              },
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            ),
            pw.SizedBox(height: 30),

            // Payment Terms
            pw.Text('Payment terms:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(po.paymentTerms, style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 40),

            // Bill To Box
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                color: PdfColors.grey100,
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('BILL TO & SHIP TO\nADDRESS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TRUPT ENTERPRISE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        pw.Text('4160, B/H Mahalaxmi Cold Storage,', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Boriavi, Anand - 387310, Gujarat, India', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('Kind Attn: PINKAL PATEL', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Contact Number: +91 96624 98664 / +91 98793 95727', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }
}
