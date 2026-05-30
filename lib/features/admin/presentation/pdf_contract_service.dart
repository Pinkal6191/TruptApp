import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../core/models/customer_model.dart';

class PdfContractService {
  static Future<void> generateAndDownloadContract({
    required String customerName,
    required String customerAddress,
    required String customerContact,
    required double oneTimeFees,
    double? price200ml,
    int? moq200ml,
    double? price500ml,
    int? moq500ml,
    double? price1L,
    int? moq1L,
    required String duration,
  }) async {
    final pdf = pw.Document();

    final dateStr = DateFormat('dd MMMM yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          final primaryColor = PdfColor.fromHex('#1E3A8A');
          final accentColor = PdfColor.fromHex('#3B82F6');
          final lightBgColor = PdfColor.fromHex('#F8FAFC');
          final textDark = PdfColor.fromHex('#1E293B');
          final textGrey = PdfColor.fromHex('#64748B');

          return [
            // Top Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TRUPT ENTERPRISE',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Premium Packaged Drinking Water',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      'PRIVATE LABEL AGREEMENT',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Date & Intro
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Date: $dateStr', style: pw.TextStyle(fontSize: 12, color: textDark, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'This Private Label Agreement ("Agreement") is made and entered into on $dateStr by and between:',
              style: pw.TextStyle(fontSize: 11, color: textDark, lineSpacing: 1.5),
            ),
            pw.SizedBox(height: 12),
            
            // Parties Block
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    height: 85,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightBgColor,
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PARTY A (Supplier)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: accentColor, fontSize: 10)),
                        pw.SizedBox(height: 6),
                        pw.Text('Trupt Enterprise', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 2),
                        pw.Text('Address: [Insert Supplier Address]', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                        pw.Text('Contact: [Insert Supplier Contact]', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Container(
                    height: 85,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: lightBgColor,
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PARTY B (Client)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: accentColor, fontSize: 10)),
                        pw.SizedBox(height: 8),
                        pw.Text(customerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                        pw.SizedBox(height: 4),
                        pw.Text('Address: $customerAddress', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                        pw.Text('Contact: $customerContact', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Terms
            pw.Text('1. FINANCIAL TERMS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
              cellStyle: pw.TextStyle(fontSize: 11, color: textDark),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              headers: ['Item Description', 'Amount / Price'],
              data: [
                ['One-Time Setup & Label Printing Fee', 'Rs. ${oneTimeFees.toStringAsFixed(2)}'],
                if (price200ml != null) ['Price per Crate (200ml Bottles)', 'Rs. ${price200ml.toStringAsFixed(2)}'],
                if (price500ml != null) ['Price per Crate (500ml Bottles)', 'Rs. ${price500ml.toStringAsFixed(2)}'],
                if (price1L != null) ['Price per Crate (1L Bottles)', 'Rs. ${price1L.toStringAsFixed(2)}'],
                ['Contract Duration', duration],
              ],
            ),
            pw.SizedBox(height: 16),

            pw.Text('2. RULES & REGULATIONS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 6),
            _buildBulletPoint('Exclusivity: ', 'Party B agrees to exclusively purchase custom-labeled water from Party A for the duration of this agreement.', textDark),
            _buildBulletPoint('Label Design: ', 'Party B is responsible for providing the label design or approving the design provided by Party A. Once approved, the One-Time Setup Fee covers initial printing. Please note that the One-Time Setup & Label Printing Fee is strictly non-refundable.', textDark),
            _buildBulletPoint('Minimum Order Quantity (MOQ): ', 'Each delivery requires a minimum order of:\n'
                '${moq200ml != null ? '• $moq200ml crates of 200ml bottles\n' : ''}'
                '${moq500ml != null ? '• $moq500ml crates of 500ml bottles\n' : ''}'
                '${moq1L != null ? '• $moq1L crates of 1L bottles\n' : ''}'
                'to qualify for the prices listed above.', textDark),
            _buildBulletPoint('Payment Terms: ', 'Payments must be made within 15 days of delivery.', textDark),
            _buildBulletPoint('Termination: ', 'Either party may terminate this agreement with a 30-day written notice.', textDark),
            pw.SizedBox(height: 12),

            // Wrap the closing and signature in a Column so it tries to stay together
            pw.Wrap(
              children: [
                pw.Text('IN WITNESS WHEREOF, the Parties have executed this Agreement as of the date first written above.', style: pw.TextStyle(fontSize: 11, color: textDark, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 30, width: double.infinity),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(width: 180, height: 1, color: PdfColors.grey600),
                        pw.SizedBox(height: 8),
                        pw.Text('For Trupt Enterprise', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: textDark)),
                        pw.SizedBox(height: 2),
                        pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                        pw.SizedBox(height: 2),
                        pw.Text('(Company Stamp)', style: pw.TextStyle(fontSize: 10, color: textGrey, fontStyle: pw.FontStyle.italic)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(width: 180, height: 1, color: PdfColors.grey600),
                        pw.SizedBox(height: 8),
                        pw.Text('For $customerName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: textDark)),
                        pw.SizedBox(height: 2),
                        pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 10, color: textGrey)),
                        pw.SizedBox(height: 2),
                        pw.Text('(Company Stamp)', style: pw.TextStyle(fontSize: 10, color: textGrey, fontStyle: pw.FontStyle.italic)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    // Save and print/download
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Contract_${customerName.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _buildBulletPoint(String title, String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 4, right: 8),
            width: 4,
            height: 4,
            decoration: const pw.BoxDecoration(
              color: PdfColors.black,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(fontSize: 11, color: color, lineSpacing: 1.5),
                children: [
                  pw.TextSpan(text: title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
