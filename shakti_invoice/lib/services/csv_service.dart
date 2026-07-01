import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/invoice.dart';

/// Exports invoices to a spreadsheet-friendly CSV file for accounting.
class CsvService {
  static String _esc(Object? v) {
    final s = (v ?? '').toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Writes a CSV of [invoices] to a temp file and returns its path.
  static Future<String> exportInvoices(List<Invoice> invoices) async {
    final rows = <String>[];
    rows.add([
      'Invoice No',
      'Date',
      'Time',
      'Customer',
      'Phone',
      'Subtotal',
      'Discount',
      'Tax',
      'Grand Total',
      'Payment',
      'Status',
      'Balance',
    ].map(_esc).join(','));

    for (final inv in invoices) {
      rows.add([
        inv.invoiceNo,
        inv.date,
        inv.time,
        inv.customer,
        inv.customerPhone ?? '',
        inv.subtotal.toStringAsFixed(2),
        inv.discount.toStringAsFixed(2),
        inv.taxAmount.toStringAsFixed(2),
        inv.grandTotal.toStringAsFixed(2),
        inv.paymentMethod,
        inv.paid,
        inv.balance.toStringAsFixed(2),
      ].map(_esc).join(','));
    }

    final dir = await getTemporaryDirectory();
    final name =
        'invoices_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
    final file = File('${dir.path}/$name');
    await file.writeAsString(rows.join('\n'));
    return file.path;
  }
}
