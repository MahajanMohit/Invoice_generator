import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../services/pdf_service.dart';
import '../services/store_settings.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _primary = Color(0xFF1a237e);
  static const Color _mid = Color(0xFF3949ab);

  final _db = DatabaseHelper();
  final _customerCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _invoiceNo = 'IC-...';
  String _dateTimeStr = '';
  Timer? _clockTimer;
  bool _loading = false;
  StoreSettings _settings = StoreSettings.defaults();

  // Each row: {name, qty, price} controllers
  final List<Map<String, TextEditingController>> _rows = [];

  @override
  void initState() {
    super.initState();
    _updateClock();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _loadInvoiceNumber();
    _loadSettings();
    _addRow();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _customerCtrl.dispose();
    for (final row in _rows) {
      row['name']!.dispose();
      row['qty']!.dispose();
      row['price']!.dispose();
    }
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    setState(() {
      _dateTimeStr = DateFormat('dd/MM/yyyy  HH:mm:ss').format(now);
    });
  }

  Future<void> _loadInvoiceNumber() async {
    final no = await _db.nextInvoiceNumber();
    if (mounted) setState(() => _invoiceNo = no);
  }

  Future<void> _loadSettings() async {
    final s = await StoreSettingsService.load();
    if (mounted) setState(() => _settings = s);
  }

  void _addRow() {
    setState(() {
      _rows.add({
        'name': TextEditingController(),
        'qty': TextEditingController(),
        'price': TextEditingController(),
      });
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    final row = _rows.removeAt(index);
    row['name']!.dispose();
    row['qty']!.dispose();
    row['price']!.dispose();
    setState(() {});
  }

  double _rowTotal(int i) {
    final qty = double.tryParse(_rows[i]['qty']!.text) ?? 0;
    final price = double.tryParse(_rows[i]['price']!.text) ?? 0;
    return qty * price;
  }

  double get _grandTotal =>
      List.generate(_rows.length, _rowTotal).fold(0, (a, b) => a + b);

  List<InvoiceItem> _buildItems() {
    final items = <InvoiceItem>[];
    for (int i = 0; i < _rows.length; i++) {
      final name = _rows[i]['name']!.text.trim();
      final qty = double.tryParse(_rows[i]['qty']!.text) ?? 0;
      final price = double.tryParse(_rows[i]['price']!.text) ?? 0;
      if (name.isNotEmpty || qty > 0 || price > 0) {
        items.add(InvoiceItem(
          itemName: name.isEmpty ? '(unnamed)' : name,
          qty: qty,
          unitPrice: price,
          total: double.parse((qty * price).toStringAsFixed(2)),
        ));
      }
    }
    return items;
  }

  void _clearForm() {
    _customerCtrl.clear();
    for (final row in _rows) {
      row['name']!.dispose();
      row['qty']!.dispose();
      row['price']!.dispose();
    }
    _rows.clear();
    _addRow();
    _loadInvoiceNumber();
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (changed == true) _loadSettings();
  }

  Future<void> _generate() async {
    final customer = _customerCtrl.text.trim();
    if (customer.isEmpty) {
      _showSnack('Please enter a customer name.', isError: true);
      return;
    }
    final items = _buildItems();
    if (items.isEmpty) {
      _showSnack('Add at least one item.', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final invoice = Invoice(
        invoiceNo: _invoiceNo,
        date: DateFormat('dd-MM-yyyy').format(now),
        time: DateFormat('HH:mm:ss').format(now),
        day: DateFormat('EEEE').format(now),
        customer: customer,
        grandTotal: double.parse(_grandTotal.toStringAsFixed(2)),
      );

      final invoiceId = await _db.insertInvoice(invoice, items);

      // Pass current store settings into PDF generation
      final pdfPath = await PdfService.generateReceipt(
        invoice: invoice,
        items: items,
        settings: _settings,
      );

      await _db.updatePdfPath(invoiceId, pdfPath);

      if (mounted) _showSuccessDialog(pdfPath, invoice);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog(String pdfPath, Invoice invoice) {
    final moneyFmt = NumberFormat('#,##0.00');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF2e7d32),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 12),
            const Text('Invoice Generated!',
                style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          '${invoice.invoiceNo}  •  ${invoice.customer}  •  Rs.${moneyFmt.format(invoice.grandTotal)}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share PDF'),
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(pdfPath)],
                  text: 'Invoice ${invoice.invoiceNo}');
              _clearForm();
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open PDF'),
            onPressed: () {
              Navigator.pop(ctx);
              OpenFilex.open(pdfPath);
              _clearForm();
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearForm();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? const Color(0xFFe53935) : const Color(0xFF2e7d32),
    ));
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _settings.displayName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            if (_settings.storeTagline.isNotEmpty)
              Text(
                _settings.storeTagline,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Invoice History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Store Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 12),
            _buildItemsCard(),
            const SizedBox(height: 12),
            _buildTotalRow(),
            const SizedBox(height: 16),
            _buildButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() => Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _invoiceNo,
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _dateTimeStr,
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerCtrl,
                decoration: InputDecoration(
                  labelText: 'Customer Name',
                  prefixIcon: const Icon(Icons.person, color: _mid),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _primary, width: 2),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
      );

  Widget _buildItemsCard() => Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Items',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _primary)),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text('Item',
                          style: TextStyle(
                              fontSize: 11, color: Colors.black54))),
                  SizedBox(width: 8),
                  SizedBox(
                      width: 64,
                      child: Text('Qty',
                          style: TextStyle(
                              fontSize: 11, color: Colors.black54))),
                  SizedBox(width: 8),
                  SizedBox(
                      width: 80,
                      child: Text('Price',
                          style: TextStyle(
                              fontSize: 11, color: Colors.black54))),
                  SizedBox(width: 8),
                  SizedBox(
                      width: 72,
                      child: Text('Total',
                          style: TextStyle(
                              fontSize: 11, color: Colors.black54))),
                  SizedBox(width: 32),
                ],
              ),
              const Divider(),
              ...List.generate(_rows.length, (i) => _buildItemRow(i)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
                style: TextButton.styleFrom(foregroundColor: _mid),
              ),
            ],
          ),
        ),
      );

  Widget _buildItemRow(int i) {
    return StatefulBuilder(
      builder: (context, rowSetState) {
        final total = _rowTotal(i);
        void onChange() {
          rowSetState(() {});
          setState(() {});
        }

        _rows[i]['qty']!.removeListener(() {});
        _rows[i]['price']!.removeListener(() {});
        _rows[i]['qty']!.addListener(onChange);
        _rows[i]['price']!.addListener(onChange);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _rows[i]['name'],
                  decoration: _inputDeco('Name'),
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _rows[i]['qty'],
                  decoration: _inputDeco('Qty'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 78,
                child: TextField(
                  controller: _rows[i]['price'],
                  decoration: _inputDeco('Price'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 70,
                child: Text(
                  total > 0 ? NumberFormat('#,##0.00').format(total) : '—',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: total > 0 ? _primary : Colors.black38,
                    fontWeight:
                        total > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.black38),
                padding: EdgeInsets.zero,
                onPressed: () => _removeRow(i),
              ),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _primary),
        ),
      );

  Widget _buildTotalRow() => Card(
        color: _primary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text(
                'Rs. ${NumberFormat('#,##0.00').format(_grandTotal)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ],
          ),
        ),
      );

  Widget _buildButtons() => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.clear),
              label: const Text('Clear'),
              onPressed: _clearForm,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: _mid),
                foregroundColor: _mid,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_loading ? 'Generating...' : 'Generate Invoice'),
              onPressed: _loading ? null : _generate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      );
}
