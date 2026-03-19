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
  bool _showLast30Days = false;

  @override
  void initState() {
    super.initState();
    // Silently purge invoices older than 30 days, then load
    _db.deleteOldInvoices(30).then((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = _showLast30Days
        ? await _db.listInvoicesForDays(30)
        : await _db.listTodayInvoices();
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
      if (d.year == today.year &&
          d.month == today.month &&
          d.day == today.day) {
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
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
      body: Column(
        children: [
          _buildToggleBar(cs),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _invoices.isEmpty
                    ? _buildEmpty(cs)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _buildList(cs),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          _ToggleChip(
            label: 'Today',
            selected: !_showLast30Days,
            cs: cs,
            onTap: () {
              if (_showLast30Days) {
                setState(() => _showLast30Days = false);
                _load();
              }
            },
          ),
          const SizedBox(width: 8),
          _ToggleChip(
            label: 'Last 30 Days',
            selected: _showLast30Days,
            cs: cs,
            onTap: () {
              if (!_showLast30Days) {
                setState(() => _showLast30Days = true);
                _load();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long,
              size: 64, color: cs.onSurface.withOpacity(0.25)),
          const SizedBox(height: 16),
          Text(
            _showLast30Days
                ? 'No invoices in the last 30 days.'
                : 'No invoices generated today.',
            style:
                TextStyle(color: cs.onSurface.withOpacity(0.45)),
          ),
          if (!_showLast30Days) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() => _showLast30Days = true);
                _load();
              },
              child: const Text('View older invoices'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme cs) {
    // Group by date label, compute per-day total
    final groups = <String, List<Invoice>>{};
    for (final inv in _invoices) {
      final label = _dateLabel(inv.date);
      groups.putIfAbsent(label, () => []).add(inv);
    }

    final sections = <Widget>[];
    groups.forEach((label, list) {
      final dayTotal = list.fold<double>(0, (s, inv) => s + inv.grandTotal);
      sections.add(_DateHeader(label: label, dayTotal: dayTotal));
      for (final inv in list) {
        sections.add(
            _InvoiceCard(invoice: inv, onTap: () => _openInvoice(inv, cs)));
      }
    });

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      children: sections,
    );
  }

  void _openInvoice(Invoice inv, ColorScheme cs) {
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
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: cs.primary)),
              Text('${inv.customer}  •  ${inv.date}',
                  style:
                      TextStyle(color: cs.onSurface.withOpacity(0.55))),
              Text(
                'Rs. ${NumberFormat('#,##0.00').format(inv.grandTotal)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.primary),
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
                        side: BorderSide(color: cs.primary),
                        foregroundColor: cs.primary,
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

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? cs.primary : cs.outline, width: 1.2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String label;
  final double dayTotal;
  const _DateHeader({required this.label, required this.dayTotal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: cs.primary,
            ),
          ),
          Text(
            'Total  Rs. ${NumberFormat('#,##0.00').format(dayTotal)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.primary.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  const _InvoiceCard({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.invoiceNo,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.customer,
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                    ),
                    if (invoice.time.isNotEmpty)
                      Text(
                        invoice.time,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.45)),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${NumberFormat('#,##0.00').format(invoice.grandTotal)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right,
                      color: cs.onSurface.withOpacity(0.25)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
