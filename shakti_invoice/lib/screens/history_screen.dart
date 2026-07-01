import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../app_state.dart';
import '../database/database_helper.dart';
import '../models/invoice.dart';
import '../services/csv_service.dart';
import '../services/store_settings.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'create_invoice_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _db = DatabaseHelper();
  List<Invoice> _invoices = [];
  bool _loading = true;
  bool _showLast30Days = true;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All'; // All | Paid | Unpaid | Partial

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() =>
        setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()));
    dataRevision.addListener(_load);
    _purgeThenLoad();
  }

  Future<void> _purgeThenLoad() async {
    final s = await StoreSettingsService.load();
    await _db.deleteOldInvoices(s.retentionDays);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    dataRevision.removeListener(_load);
    super.dispose();
  }

  List<Invoice> get _filtered {
    return _invoices.where((inv) {
      if (_statusFilter != 'All' && inv.paid != _statusFilter) return false;
      if (_searchQuery.isEmpty) return true;
      return inv.invoiceNo.toLowerCase().contains(_searchQuery) ||
          inv.customer.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final list = _showLast30Days
        ? await _db.listInvoicesForDays(90)
        : await _db.listTodayInvoices();
    if (mounted) {
      setState(() {
        _invoices = list;
        _loading = false;
      });
    }
  }

  String _dateLabel(String date) {
    final d = parseDbDate(date);
    if (d == null) return date;
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
  }

  Future<void> _exportCsv() async {
    if (_filtered.isEmpty) {
      _snack('Nothing to export.');
      return;
    }
    try {
      final path = await CsvService.exportInvoices(_filtered);
      await Share.shareXFiles([XFile(path, mimeType: 'text/csv')],
          subject: 'Invoice export');
    } catch (e) {
      _snack('Export failed: $e', error: true);
    }
  }

  void _snack(String m, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: error ? Colors.red : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GradientAppBar(
        automaticallyImplyLeading: false,
        title: const Text('Invoices'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          _toggleBar(cs),
          _searchBar(cs),
          _statusChips(cs),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.receipt_long,
                        message: _showLast30Days
                            ? 'No invoices found.'
                            : 'No invoices generated today.')
                    : RefreshIndicator(onRefresh: _load, child: _list(cs)),
          ),
        ],
      ),
    );
  }

  Widget _toggleBar(ColorScheme cs) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: cs.surfaceContainerLow,
        child: Row(
          children: [
            _chip('Today', !_showLast30Days, () {
              if (_showLast30Days) {
                setState(() => _showLast30Days = false);
                _load();
              }
            }, cs),
            const SizedBox(width: 8),
            _chip('Recent', _showLast30Days, () {
              if (!_showLast30Days) {
                setState(() => _showLast30Days = true);
                _load();
              }
            }, cs),
          ],
        ),
      );

  Widget _chip(String label, bool sel, VoidCallback onTap, ColorScheme cs) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? cs.primary : cs.outline),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  color: sel ? Colors.white : cs.onSurface)),
        ),
      );

  Widget _searchBar(ColorScheme cs) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by customer or invoice no…',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => _searchCtrl.clear())
                : null,
          ),
        ),
      );

  Widget _statusChips(ColorScheme cs) => SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final s in const ['All', 'Paid', 'Partial', 'Unpaid'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s),
                  selected: _statusFilter == s,
                  onSelected: (_) => setState(() => _statusFilter = s),
                ),
              ),
          ],
        ),
      );

  Widget _list(ColorScheme cs) {
    final groups = <String, List<Invoice>>{};
    for (final inv in _filtered) {
      groups.putIfAbsent(_dateLabel(inv.date), () => []).add(inv);
    }
    final sections = <Widget>[];
    groups.forEach((label, list) {
      final dayTotal = list.fold<double>(0, (s, i) => s + i.grandTotal);
      sections.add(_DateHeader(label: label, dayTotal: dayTotal));
      for (final inv in list) {
        sections.add(_InvoiceCard(invoice: inv, onTap: () => _openSheet(inv)));
      }
    });
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      children: sections,
    );
  }

  void _openSheet(Invoice inv) {
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.invoiceNo,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Theme.of(ctx).colorScheme.primary)),
                        Text('${inv.customer}  •  ${inv.date}',
                            style: TextStyle(
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6))),
                      ],
                    ),
                  ),
                  StatusPill(label: inv.paid, color: paymentColor(inv.paid)),
                ],
              ),
              const SizedBox(height: 6),
              Text(money(inv.grandTotal),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Theme.of(ctx).colorScheme.primary)),
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _action(ctx, Icons.open_in_new, 'Open', () {
                    Navigator.pop(ctx);
                    if (inv.pdfPath != null) OpenFilex.open(inv.pdfPath!);
                  }),
                  _action(ctx, Icons.share, 'Share', () {
                    Navigator.pop(ctx);
                    if (inv.pdfPath != null) {
                      Share.shareXFiles([XFile(inv.pdfPath!)],
                          text: 'Invoice ${inv.invoiceNo}');
                    }
                  }),
                  _action(ctx, Icons.edit, 'Edit', () async {
                    Navigator.pop(ctx);
                    await _edit(inv);
                  }),
                  _action(ctx, Icons.copy, 'Duplicate', () async {
                    Navigator.pop(ctx);
                    await _duplicate(inv);
                  }),
                  if (inv.paid != 'Paid')
                    _action(ctx, Icons.check_circle, 'Mark Paid', () async {
                      Navigator.pop(ctx);
                      await _db.markInvoicePaid(inv.id!);
                      pingData();
                    }),
                  _action(ctx, Icons.delete_outline, 'Delete', () async {
                    Navigator.pop(ctx);
                    await _confirmDelete(inv);
                  }, danger: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext ctx,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool danger = false,
  }) =>
      SizedBox(
        width: 96,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            foregroundColor:
                danger ? Colors.red : Theme.of(ctx).colorScheme.primary,
          ),
          child: Column(
            children: [
              Icon(icon, size: 20),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );

  Future<void> _edit(Invoice inv) async {
    final full = await _db.getInvoiceById(inv.id!);
    if (full == null || !mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => CreateInvoiceScreen(editInvoice: full)));
  }

  Future<void> _duplicate(Invoice inv) async {
    final full = await _db.getInvoiceById(inv.id!);
    if (full == null || !mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CreateInvoiceScreen(duplicateFrom: full)));
  }

  Future<void> _confirmDelete(Invoice inv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: Text(
            '${inv.invoiceNo} for ${inv.customer} will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _db.deleteInvoice(inv.id!);
      pingData();
      _snack('Invoice deleted.');
    }
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
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: cs.primary)),
          Text('Total  ${money(dayTotal)}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary.withOpacity(0.75))),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(invoice.invoiceNo,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: cs.primary)),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(
                            label: invoice.paid,
                            color: paymentColor(invoice.paid)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(invoice.customer,
                        style: TextStyle(fontSize: 13, color: cs.onSurface)),
                    Text('${invoice.time}  •  ${invoice.paymentMethod}',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.45))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(money(invoice.grandTotal),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: cs.primary)),
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
