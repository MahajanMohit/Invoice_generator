import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/invoice.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Color _primary = Color(0xFF1a237e);
  static const Color _mid = Color(0xFF3949ab);

  final _db = DatabaseHelper();
  List<Invoice> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _db.listInvoices();
    if (mounted) {
      setState(() {
        _invoices = list;
        _loading = false;
      });
    }
  }

  String _dateLabel(String date) {
    // date stored as DD-MM-YYYY
    try {
      final parts = date.split('-');
      if (parts.length != 3) return date;
      final d = DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      if (d.year == today.year && d.month == today.month && d.day == today.day) {
        return 'Today';
      }
      if (d.year == yesterday.year &&
          d.month == yesterday.month &&
          d.day == yesterday.day) {
        return 'Yesterday';
      }
      return DateFormat('d MMM yyyy').format(d);
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _mid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text('Invoice History',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.black26),
                      SizedBox(height: 16),
                      Text('No invoices yet.',
                          style: TextStyle(color: Colors.black45)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildList(),
                ),
    );
  }

  Widget _buildList() {
    // Group by date label
    final groups = <String, List<Invoice>>{};
    for (final inv in _invoices) {
      final label = _dateLabel(inv.date);
      groups.putIfAbsent(label, () => []).add(inv);
    }

    final sections = <Widget>[];
    groups.forEach((label, list) {
      sections.add(_DateHeader(label: label));
      for (final inv in list) {
        sections.add(_InvoiceCard(invoice: inv, onTap: () => _openInvoice(inv)));
      }
    });

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      children: sections,
    );
  }

  void _openInvoice(Invoice inv) {
    if (inv.pdfPath == null || inv.pdfPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF not available for this invoice.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(inv.invoiceNo,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _primary)),
              Text('${inv.customer}  •  ${inv.date}',
                  style: const TextStyle(color: Colors.black54)),
              Text(
                'Rs. ${NumberFormat('#,##0.00').format(inv.grandTotal)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _primary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open PDF'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        OpenFilex.open(inv.pdfPath!);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Share.shareXFiles([XFile(inv.pdfPath!)],
                            text: 'Invoice ${inv.invoiceNo}');
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _mid),
                        foregroundColor: _mid,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF1a237e),
          ),
        ),
      );
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  const _InvoiceCard({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.invoiceNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1a237e),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.customer,
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (invoice.time.isNotEmpty)
                      Text(
                        invoice.time,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${NumberFormat('#,##0.00').format(invoice.grandTotal)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1a237e),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, color: Colors.black26),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
