import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import 'store_settings.dart';

class PdfService {
  static const PdfColor _primary = PdfColor.fromInt(0xFF1a237e);
  static const PdfColor _mid = PdfColor.fromInt(0xFF3949ab);
  static const PdfColor _alt = PdfColor.fromInt(0xFFf5f5f5);
  static const PdfColor _grid = PdfColor.fromInt(0xFFc5cae9);
  static const PdfColor _footer = PdfColor.fromInt(0xFF607d8b);

  /// Generates a 58mm-width thermal receipt PDF and returns its file path.
  static Future<String> generateReceipt({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required StoreSettings settings,
  }) async {
    final doc = pw.Document();
    final cur = settings.currencySymbol;

    // Count the optional total lines so the page height fits.
    int extraTotalLines = 1; // subtotal
    if (invoice.discount > 0) extraTotalLines++;
    if (invoice.taxAmount > 0) extraTotalLines++;
    if (invoice.previousBalance > 0) extraTotalLines++;
    extraTotalLines++; // payment method
    final noteLines = (invoice.notes ?? '').trim().isEmpty ? 0 : 2;

    const pageWidth = 58 * PdfPageFormat.mm;
    final pageHeight = (46 +
            items.length * 10 +
            extraTotalLines * 6 +
            noteLines * 5 +
            26) *
        PdfPageFormat.mm;
    final pageFormat =
        PdfPageFormat(pageWidth, pageHeight, marginAll: 2 * PdfPageFormat.mm);

    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              settings.displayName,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 9, color: _primary),
              textAlign: pw.TextAlign.center,
            ),
            if (settings.storeTagline.isNotEmpty) ...[
              pw.SizedBox(height: 1 * PdfPageFormat.mm),
              pw.Text(settings.storeTagline,
                  style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      fontSize: 6.5,
                      color: _mid),
                  textAlign: pw.TextAlign.center),
            ],
            if (settings.storePhone.trim().isNotEmpty) ...[
              pw.SizedBox(height: 0.5 * PdfPageFormat.mm),
              pw.Text('Ph: ${settings.storePhone}',
                  style: const pw.TextStyle(fontSize: 6.5, color: _footer),
                  textAlign: pw.TextAlign.center),
            ],
            pw.SizedBox(height: 1 * PdfPageFormat.mm),
            pw.Divider(color: _primary, thickness: 1),
            pw.Text('TAX INVOICE',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 7, color: _mid),
                textAlign: pw.TextAlign.center),
            pw.Divider(color: _grid, thickness: 0.5),
            pw.SizedBox(height: 1 * PdfPageFormat.mm),

            _metaRow('Invoice', invoice.invoiceNo),
            _metaRow('Date', '${invoice.date}  ${invoice.time}'),
            _metaRow('Customer', invoice.customer),
            if ((invoice.customerPhone ?? '').trim().isNotEmpty)
              _metaRow('Phone', invoice.customerPhone!),
            pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
            pw.Divider(color: _grid, thickness: 0.5),
            pw.SizedBox(height: 1 * PdfPageFormat.mm),

            // Items table
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3.2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.7),
                3: const pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _primary),
                  children: [
                    _tableHeader('Item'),
                    _tableHeader('Qty'),
                    _tableHeader('Price'),
                    _tableHeader('Total'),
                  ],
                ),
                for (int i = 0; i < items.length; i++)
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: i % 2 == 1 ? _alt : PdfColors.white),
                    children: [
                      _tableCell(items[i].itemName, align: pw.TextAlign.left),
                      _tableCell(_fmt(items[i].qty), align: pw.TextAlign.right),
                      _tableCell(_fmtMoney(items[i].unitPrice),
                          align: pw.TextAlign.right),
                      _tableCell(_fmtMoney(items[i].total),
                          align: pw.TextAlign.right),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
            pw.Divider(color: _grid, thickness: 0.5),

            // Totals block
            _totalRow('Subtotal', '$cur ${_fmtMoney(invoice.subtotal)}'),
            if (invoice.discount > 0)
              _totalRow(
                  invoice.discountType == 'percent'
                      ? 'Discount (${_fmt(invoice.discountValue)}%)'
                      : 'Discount',
                  '- $cur ${_fmtMoney(invoice.discount)}'),
            if (invoice.taxAmount > 0)
              _totalRow(
                  '${settings.taxLabel} (${_fmt(invoice.taxRate)}%)',
                  '$cur ${_fmtMoney(invoice.taxAmount)}'),
            if (invoice.previousBalance > 0)
              _totalRow('Previous Balance',
                  '$cur ${_fmtMoney(invoice.previousBalance)}'),
            pw.SizedBox(height: 1 * PdfPageFormat.mm),
            pw.Divider(color: _primary, thickness: 1),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('GRAND TOTAL',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: _primary)),
                pw.Text('$cur ${_fmtMoney(invoice.grandTotal)}',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: _primary)),
              ],
            ),
            pw.SizedBox(height: 1 * PdfPageFormat.mm),
            _totalRow('Payment', invoice.paymentMethod),
            if (invoice.paid != 'Paid')
              _totalRow('Status',
                  '${invoice.paid}  (Bal: $cur ${_fmtMoney(invoice.balance)})'),

            if ((invoice.notes ?? '').trim().isNotEmpty) ...[
              pw.SizedBox(height: 1 * PdfPageFormat.mm),
              pw.Divider(color: _grid, thickness: 0.5),
              pw.Text('Note: ${invoice.notes}',
                  style: const pw.TextStyle(fontSize: 6, color: _footer)),
            ],

            pw.SizedBox(height: 1.5 * PdfPageFormat.mm),
            pw.Divider(color: _grid, thickness: 0.5),
            if (settings.footerLine1.isNotEmpty)
              pw.Text(settings.footerLine1,
                  style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      fontSize: 6,
                      color: _footer),
                  textAlign: pw.TextAlign.center),
            if (settings.footerLine2.isNotEmpty) ...[
              pw.SizedBox(height: 0.5 * PdfPageFormat.mm),
              pw.Text(settings.footerLine2,
                  style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      fontSize: 6,
                      color: _footer),
                  textAlign: pw.TextAlign.center),
            ],
          ],
        );
      },
    ));

    final docsDir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final yearMonth = '${now.year}${DateFormat('MM').format(now)}';
    final folder = Directory('${docsDir.path}/invoices/$yearMonth');
    await folder.create(recursive: true);

    final safeCustomer =
        invoice.customer.replaceAll(RegExp(r'[^a-zA-Z0-9 _\-]'), '_').trim();
    final filename = '${invoice.invoiceNo}_${safeCustomer}_${invoice.date}.pdf';
    final filePath = '${folder.path}/$filename';

    final file = File(filePath);
    await file.writeAsBytes(await doc.save());
    return filePath;
  }

  static pw.Widget _metaRow(String label, String value) => pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(
              text: '$label: ',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
          pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 7)),
        ]),
      );

  static pw.Widget _totalRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 0.3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 7, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static pw.Widget _tableHeader(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(2),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 6,
                color: PdfColors.white),
            textAlign: pw.TextAlign.center),
      );

  static pw.Widget _tableCell(String text,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(2),
        child: pw.Text(text,
            style: const pw.TextStyle(fontSize: 6.5), textAlign: align),
      );

  static String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  static String _fmtMoney(double v) => NumberFormat('#,##0.00').format(v);
}
