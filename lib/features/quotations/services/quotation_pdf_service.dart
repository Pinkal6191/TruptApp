import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/quotation_model.dart';

class QuotationPdfService {
  static Future<void> generateAndShareQuotation(QuotationModel quotation) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    final String quoteNo = quotation.quotationNumber.isNotEmpty 
        ? quotation.quotationNumber 
        : 'TE/Q/${DateFormat('yyyyMMdd').format(quotation.createdAt)}/${quotation.id.substring(0, 4).toUpperCase()}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Block
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TRUPT ENTERPRISE', style: pw.TextStyle(font: boldFont, fontSize: 24, color: PdfColors.blue900)),
                      pw.SizedBox(height: 4),
                      pw.Text('4160, B/H Mahalaxmi Cold Storage, Boriavi,', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Anand, Gujarat - 387310', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Phone: +91 96624 98664, +91 98793 95727', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Email: truptenterprise26@gmail.com', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Website: truptenterprise.com', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text('GSTIN: 24AAZFT5241K1ZK', style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.black)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('QUOTATION', style: pw.TextStyle(font: boldFont, fontSize: 28, color: PdfColors.blue800)),
                      pw.SizedBox(height: 4),
                      pw.Text('Quote Type: ${quotation.quotationType}', style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.blue900)),
                      pw.SizedBox(height: 8),
                      pw.Text('Date: ${DateFormat('dd MMM yyyy').format(quotation.createdAt)}', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('Valid Until: ${DateFormat('dd MMM yyyy').format(quotation.validUntil)}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.red700)),
                      pw.Text('Quote No: $quoteNo', style: pw.TextStyle(font: boldFont, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColors.blue900, thickness: 1.5),
              pw.SizedBox(height: 16),

              // Proposed To / Billed To
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Quotation For:', style: pw.TextStyle(font: boldFont, fontSize: 12, color: PdfColors.blue900)),
                        pw.SizedBox(height: 4),
                        pw.Text(quotation.shopName, style: pw.TextStyle(font: boldFont, fontSize: 14)),
                        if (quotation.contactPerson.isNotEmpty)
                          pw.Text('Attn: ${quotation.contactPerson}', style: pw.TextStyle(font: font, fontSize: 11)),
                        if (quotation.customerAddress.isNotEmpty)
                          pw.Text('Address: ${quotation.customerAddress}', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey800)),
                        pw.Text('Mobile: ${quotation.customerMobile}', style: pw.TextStyle(font: font, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Items Table
              _buildItemsTable(quotation.items, font, boldFont),
              pw.SizedBox(height: 20),

              // Financial Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        if (quotation.withGst) ...[
                          _buildTotalRow('Taxable Subtotal:', quotation.subtotal, font),
                          pw.SizedBox(height: 4),
                          _buildTotalRow('SGST (2.5%):', quotation.gstAmount / 2, font),
                          pw.SizedBox(height: 4),
                          _buildTotalRow('CGST (2.5%):', quotation.gstAmount / 2, font),
                          pw.Divider(color: PdfColors.grey300),
                        ],
                        _buildTotalRow('Estimated Grand Total:', quotation.finalAmount, boldFont, isTotal: true, color: PdfColors.blue900),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Custom Terms and Conditions Block
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Terms & Conditions:', style: pw.TextStyle(font: boldFont, fontSize: 11, color: PdfColors.blue900)),
                        pw.SizedBox(height: 4),
                        if (quotation.termsConditions.isNotEmpty)
                          pw.Text(quotation.termsConditions, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey800))
                        else
                          _buildDefaultTerms(quotation.quotationType, font),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 30),
                  // Signature Placeholder
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('For, TRUPT ENTERPRISE', style: pw.TextStyle(font: boldFont, fontSize: 10)),
                        pw.SizedBox(height: 35),
                        pw.Divider(color: PdfColors.black, thickness: 0.5),
                        pw.SizedBox(height: 2),
                        pw.Text('Authorized Signatory', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('Subject to Anand Jurisdiction | Thank you for your inquiry!', style: pw.TextStyle(font: boldFont, fontSize: 10, color: PdfColors.blue900)),
              ),
            ],
          );
        },
      ),
    );

    // Prompt user to print or download the PDF in proper format
    final Uint8List bytes = await pdf.save();
    
    // Printing layout handles printing / downloading in direct high fidelity
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Quotation_${quotation.shopName.replaceAll(" ", "_")}_$quoteNo.pdf',
    );
  }

  static pw.Widget _buildItemsTable(List<QuotationItemModel> items, pw.Font font, pw.Font boldFont) {
    return pw.TableHelper.fromTextArray(
      headers: ['Product / Description', 'Qty', 'Unit', 'Rate/Unit', 'Total Amount'],
      data: items.map((item) => [
        item.productName,
        item.quantity.toString(),
        item.unitType,
        'Rs. ${item.pricePerUnit.toStringAsFixed(2)}',
        'Rs. ${(item.quantity * item.pricePerUnit).toStringAsFixed(2)}',
      ]).toList(),
      headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
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
            fontSize: isTotal ? 12 : 10,
          ),
        ),
        pw.Text(
          'Rs. ${value.toStringAsFixed(2)}',
          style: pw.TextStyle(
            font: font,
            fontSize: isTotal ? 12 : 10,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildDefaultTerms(String type, pw.Font font) {
    List<String> terms = [];
    if (type == 'Custom Branding') {
      terms = [
        '1. 50% advance payment required upon order confirmation.',
        '2. Delivery: 7-10 working days from artwork confirmation.',
        '3. Customized label printing charges are applicable for first-time orders.',
        '4. Quotation is valid for 30 days.'
      ];
    } else if (type == 'Distributor Supply') {
      terms = [
        '1. Security deposit and signed contract required for distributor status.',
        '2. Supply schedules will follow standard weekly dispatch rotations.',
        '3. Payments must be processed as per standard billing cycles.',
        '4. Quotation is valid for 30 days.'
      ];
    } else {
      terms = [
        '1. Standard payment terms upon receipt of order.',
        '2. Standard deliveries will complete in 2-3 business days.',
        '3. Crates remain the property of Trupt Enterprise and must be returned.',
        '4. Quotation is valid for 30 days.'
      ];
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: terms.map((t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Text(t, style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey800)),
      )).toList(),
    );
  }
}
