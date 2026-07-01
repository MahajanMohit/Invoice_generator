import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../app_state.dart';
import '../database/database_helper.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/product.dart';
import '../services/invoice_calculator.dart';
import '../services/pdf_service.dart';
import '../services/store_settings.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class CreateInvoiceScreen extends StatefulWidget {
  /// When provided, the screen edits this invoice instead of creating one.
  final Invoice? editInvoice;

  /// When provided (and not editing), pre-fills a fresh invoice from this one.
  final Invoice? duplicateFrom;

  const CreateInvoiceScreen(
      {super.key, this.editInvoice, this.duplicateFrom});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _db = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  final _customerCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _prevBalanceCtrl = TextEditingController();
  final _receivedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  double _customerDues = 0; // detected unpaid dues for the entered customer

  final List<_ItemRow> _rows = [];

  StoreSettings _settings = StoreSettings.defaults();
  String _invoiceNo = '...';
  String _dateStr = '';
  String _timeStr = '';
  String _discountType = 'flat'; // 'flat' | 'percent'
  String _payMethod = 'Cash';
  String _status = 'Paid'; // Paid | Unpaid | Partial
  bool _loading = false;
  bool _ready = false;

  bool get _isEditing => widget.editInvoice != null;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final s = await StoreSettingsService.load();
    final now = DateTime.now();
    _settings = s;
    _payMethod = s.defaultPaymentMethod;
    _taxCtrl.text = s.defaultTaxRate > 0 ? qtyFmt(s.defaultTaxRate) : '';

    if (_isEditing) {
      final inv = widget.editInvoice!;
      _invoiceNo = inv.invoiceNo;
      _dateStr = inv.date;
      _timeStr = inv.time;
      _prefillContent(inv);
    } else {
      _invoiceNo = await _db.nextInvoiceNumber(prefix: s.invoicePrefix);
      _dateStr = DateFormat('dd-MM-yyyy').format(now);
      _timeStr = DateFormat('HH:mm:ss').format(now);
      if (widget.duplicateFrom != null) {
        _prefillContent(widget.duplicateFrom!);
      } else {
        _addRow();
      }
    }
    if (mounted) setState(() => _ready = true);
    if (_customerCtrl.text.trim().isNotEmpty) _checkDues();
  }

  void _prefillContent(Invoice inv) {
    _customerCtrl.text = inv.customer;
    _phoneCtrl.text = inv.customerPhone ?? '';
    _notesCtrl.text = inv.notes ?? '';
    _discountType = inv.discountType;
    _discountCtrl.text =
        inv.discountValue > 0 ? qtyFmt(inv.discountValue) : '';
    _taxCtrl.text = inv.taxRate > 0 ? qtyFmt(inv.taxRate) : '';
    _prevBalanceCtrl.text =
        inv.previousBalance > 0 ? inv.previousBalance.toStringAsFixed(2) : '';
    _payMethod = inv.paymentMethod;
    _status = inv.paid;
    if (inv.paid == 'Partial') {
      _receivedCtrl.text = (inv.grandTotal - inv.balance).toStringAsFixed(2);
    }
    for (final it in inv.items) {
      final row = _ItemRow(
        name: it.itemName,
        qty: qtyFmt(it.qty),
        price: it.unitPrice.toStringAsFixed(2),
      );
      row.attach(_recalc);
      _rows.add(row);
    }
    if (_rows.isEmpty) _addRow();
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _phoneCtrl.dispose();
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    _prevBalanceCtrl.dispose();
    _receivedCtrl.dispose();
    _notesCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  // ── Row management ──────────────────────────────────────────────────────────

  void _addRow([Product? product]) {
    final row = _ItemRow(
      name: product?.name ?? '',
      qty: product != null ? '1' : '',
      price: product != null ? product.price.toStringAsFixed(2) : '',
    );
    row.attach(_recalc);
    setState(() => _rows.add(row));
  }

  void _removeRow(int i) {
    if (_rows.length <= 1) {
      _rows[i].set('', '', '');
    } else {
      _rows.removeAt(i).dispose();
    }
    _recalc();
  }

  void _recalc() => setState(() {});

  // ── Totals ──────────────────────────────────────────────────────────────────

  double get _subtotal {
    double s = 0;
    for (final r in _rows) {
      s += r.lineTotal;
    }
    return s;
  }

  Totals get _totals => computeTotals(
        subtotal: _subtotal,
        discountType: _discountType,
        discountValue: double.tryParse(_discountCtrl.text) ?? 0,
        taxRate: double.tryParse(_taxCtrl.text) ?? 0,
        previousBalance: double.tryParse(_prevBalanceCtrl.text) ?? 0,
      );

  /// Look up any unpaid dues for the current customer and surface a shortcut.
  Future<void> _checkDues() async {
    final name = _customerCtrl.text.trim();
    if (name.isEmpty) {
      if (_customerDues != 0) setState(() => _customerDues = 0);
      return;
    }
    final dues = await _db.customerOutstanding(name,
        excludeInvoiceId: widget.editInvoice?.id);
    if (mounted) setState(() => _customerDues = dues);
  }

  // ── Pickers ─────────────────────────────────────────────────────────────────

  Future<void> _pickCustomer() async {
    final selected = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => const _CustomerPickerSheet(),
    );
    if (selected != null) {
      setState(() {
        _customerCtrl.text = selected.name;
        if ((selected.phone ?? '').isNotEmpty) {
          _phoneCtrl.text = selected.phone!;
        }
      });
      _checkDues();
    }
  }

  Future<void> _pickFromCatalog() async {
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => const _ProductPickerSheet(),
    );
    if (selected != null) {
      // Reuse the first empty row if present, else append.
      final empty = _rows.indexWhere((r) => r.isEmpty);
      if (empty >= 0) {
        _rows[empty]
            .set(selected.name, '1', selected.price.toStringAsFixed(2));
        _recalc();
      } else {
        _addRow(selected);
      }
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────────

  List<InvoiceItem> _buildItems() {
    final items = <InvoiceItem>[];
    for (final r in _rows) {
      if (r.isEmpty) continue;
      final qty = double.tryParse(r.qty.text) ?? 0;
      final price = double.tryParse(r.price.text) ?? 0;
      final name = r.name.text.trim();
      if (name.isEmpty && qty == 0 && price == 0) continue;
      items.add(InvoiceItem(
        itemName: name.isEmpty ? '(unnamed)' : name,
        qty: qty,
        unitPrice: price,
        total: double.parse((qty * price).toStringAsFixed(2)),
      ));
    }
    return items;
  }

  Future<void> _save() async {
    final customer = _customerCtrl.text.trim();
    if (customer.isEmpty) {
      _snack('Please enter a customer name.', error: true);
      return;
    }
    final items = _buildItems();
    if (items.isEmpty) {
      _snack('Add at least one item.', error: true);
      return;
    }
    final t = _totals;
    double balance;
    if (_status == 'Paid') {
      balance = 0;
    } else if (_status == 'Unpaid') {
      balance = t.grandTotal;
    } else {
      final received = double.tryParse(_receivedCtrl.text) ?? 0;
      balance = (t.grandTotal - received).clamp(0, t.grandTotal).toDouble();
    }

    setState(() => _loading = true);
    try {
      final invoice = Invoice(
        id: widget.editInvoice?.id,
        invoiceNo: _invoiceNo,
        date: _dateStr,
        time: _timeStr,
        day: DateFormat('EEEE')
            .format(parseDbDate(_dateStr) ?? DateTime.now()),
        customer: customer,
        customerPhone: _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        subtotal: t.subtotal,
        discount: t.discount,
        discountType: _discountType,
        discountValue: double.tryParse(_discountCtrl.text) ?? 0,
        taxRate: double.tryParse(_taxCtrl.text) ?? 0,
        taxAmount: t.tax,
        previousBalance: t.previousBalance,
        grandTotal: t.grandTotal,
        paid: _status,
        paymentMethod: _payMethod,
        balance: balance,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        pdfPath: widget.editInvoice?.pdfPath,
        items: items,
      );

      int invoiceId;
      if (_isEditing) {
        await _db.updateInvoice(invoice);
        invoiceId = invoice.id!;
      } else {
        invoiceId = await _db.insertInvoice(invoice, items);
      }

      final pdfPath = await PdfService.generateReceipt(
          invoice: invoice, items: items, settings: _settings);
      await _db.updatePdfPath(invoiceId, pdfPath);

      pingData();
      if (mounted) _showSuccess(pdfPath, invoice);
    } catch (e) {
      if (mounted) _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess(String pdfPath, Invoice invoice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                  color: AppTheme.success, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 12),
            Text(_isEditing ? 'Invoice Updated!' : 'Invoice Generated!',
                style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          '${invoice.invoiceNo}  •  ${invoice.customer}\n${money(invoice.grandTotal)}',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(pdfPath)],
                  text: 'Invoice ${invoice.invoiceNo}');
              Navigator.pop(context, true);
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
            onPressed: () {
              Navigator.pop(ctx);
              OpenFilex.open(pdfPath);
              Navigator.pop(context, true);
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.danger : AppTheme.success,
    ));
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: GradientAppBar(
        title: Text(_isEditing ? 'Edit Invoice' : 'New Invoice'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _customerCard(cs),
            const SizedBox(height: 12),
            _itemsCard(cs),
            const SizedBox(height: 12),
            _chargesCard(cs),
            const SizedBox(height: 12),
            _paymentCard(cs),
            const SizedBox(height: 12),
            _totalsCard(cs),
            const SizedBox(height: 16),
            _buttons(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _customerCard(ColorScheme cs) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_invoiceNo,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: cs.primary)),
                  Text('$_dateStr  $_timeStr',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerCtrl,
                textCapitalization: TextCapitalization.words,
                onEditingComplete: () {
                  _checkDues();
                  FocusScope.of(context).nextFocus();
                },
                decoration: InputDecoration(
                  labelText: 'Customer Name',
                  prefixIcon: Icon(Icons.person, color: cs.primary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.contacts),
                    tooltip: 'Pick saved customer',
                    onPressed: _pickCustomer,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone, color: cs.primary),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _itemsCard(ColorScheme cs) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(icon: Icons.shopping_cart, title: 'Items'),
              Row(
                children: [
                  Expanded(
                      flex: 4,
                      child: Text('Item',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant))),
                  const SizedBox(width: 6),
                  Expanded(
                      flex: 2,
                      child: Text('Qty',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant))),
                  const SizedBox(width: 6),
                  Expanded(
                      flex: 2,
                      child: Text('Price',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant))),
                  const SizedBox(width: 6),
                  Expanded(
                      flex: 3,
                      child: Text('Total',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant))),
                  const SizedBox(width: 34),
                ],
              ),
              const Divider(),
              ...List.generate(_rows.length, (i) => _buildRow(i, cs)),
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _addRow(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _pickFromCatalog,
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('Catalog'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildRow(int i, ColorScheme cs) {
    final row = _rows[i];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: TextField(
              controller: row.name,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 13),
              decoration: _deco('Name'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.qty,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              style: const TextStyle(fontSize: 13),
              decoration: _deco('Qty'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              style: const TextStyle(fontSize: 13),
              decoration: _deco('Price'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(
              row.lineTotal > 0 ? amount(row.lineTotal) : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      row.lineTotal > 0 ? FontWeight.w600 : FontWeight.normal,
                  color:
                      row.lineTotal > 0 ? cs.primary : cs.onSurfaceVariant),
            ),
          ),
          SizedBox(
            width: 34,
            child: IconButton(
              icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
              padding: EdgeInsets.zero,
              onPressed: () => _removeRow(i),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chargesCard(ColorScheme cs) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                  icon: Icons.percent, title: 'Discount, Tax & Dues'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                      ],
                      onChanged: (_) => _recalc(),
                      decoration:
                          const InputDecoration(labelText: 'Discount'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ToggleButtons(
                    isSelected: [
                      _discountType == 'flat',
                      _discountType == 'percent'
                    ],
                    onPressed: (idx) => setState(() {
                      _discountType = idx == 0 ? 'flat' : 'percent';
                    }),
                    borderRadius: BorderRadius.circular(8),
                    constraints:
                        const BoxConstraints(minHeight: 44, minWidth: 46),
                    children: [
                      Text(_settings.currencySymbol),
                      const Text('%'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _taxCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                onChanged: (_) => _recalc(),
                decoration: InputDecoration(
                  labelText: '${_settings.taxLabel} rate',
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prevBalanceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                onChanged: (_) => _recalc(),
                decoration: InputDecoration(
                  labelText: 'Previous Balance / Old Dues',
                  prefixText: '${_settings.currencySymbol} ',
                  helperText: 'Added on top of the Grand Total',
                ),
              ),
              if (_customerDues > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Material(
                    color: AppTheme.warning.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        _prevBalanceCtrl.text =
                            _customerDues.toStringAsFixed(2);
                        _recalc();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 18, color: AppTheme.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This customer has ${money(_customerDues)} in unpaid dues.',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            const Text('ADD',
                                style: TextStyle(
                                    color: AppTheme.warning,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _paymentCard(ColorScheme cs) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                  icon: Icons.payments, title: 'Payment'),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const ['Cash', 'UPI', 'Card', 'Credit'])
                    ChoiceChip(
                      label: Text(m),
                      selected: _payMethod == m,
                      onSelected: (_) => setState(() => _payMethod = m),
                    ),
                ],
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in const ['Paid', 'Partial', 'Unpaid'])
                    ChoiceChip(
                      label: Text(s),
                      selected: _status == s,
                      selectedColor: paymentColor(s).withOpacity(0.2),
                      onSelected: (_) => setState(() => _status = s),
                    ),
                ],
              ),
              if (_status == 'Partial') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _receivedCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  onChanged: (_) => _recalc(),
                  decoration: InputDecoration(
                    labelText: 'Amount received',
                    prefixText: '${_settings.currencySymbol} ',
                    helperText: 'Balance: ${money(_partialBalance)}',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true),
              ),
            ],
          ),
        ),
      );

  double get _partialBalance {
    final received = double.tryParse(_receivedCtrl.text) ?? 0;
    return (_totals.grandTotal - received)
        .clamp(0, _totals.grandTotal)
        .toDouble();
  }

  Widget _totalsCard(ColorScheme cs) {
    final t = _totals;
    return Card(
      color: cs.primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _totLine('Subtotal', money(t.subtotal), Colors.white70),
            if (t.discount > 0)
              _totLine('Discount', '- ${money(t.discount)}', Colors.white70),
            if (t.tax > 0)
              _totLine('${_settings.taxLabel} (${_taxCtrl.text}%)',
                  money(t.tax), Colors.white70),
            if (t.previousBalance > 0)
              _totLine('Previous Balance', money(t.previousBalance),
                  Colors.white70),
            const Divider(color: Colors.white24, height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Grand Total',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17)),
                Text(money(t.grandTotal),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 21)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _totLine(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 13)),
            Text(value, style: TextStyle(color: color, fontSize: 13)),
          ],
        ),
      );

  Widget _buttons() => Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Icon(_isEditing ? Icons.save : Icons.picture_as_pdf),
              label: Text(_loading
                  ? 'Working…'
                  : (_isEditing ? 'Save Changes' : 'Generate Invoice')),
              onPressed: _loading ? null : _save,
            ),
          ),
        ],
      );

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      );
}

/// Holds the three controllers for one editable item row.
class _ItemRow {
  final TextEditingController name;
  final TextEditingController qty;
  final TextEditingController price;
  VoidCallback? _listener;

  _ItemRow({String name = '', String qty = '', String price = ''})
      : name = TextEditingController(text: name),
        qty = TextEditingController(text: qty),
        price = TextEditingController(text: price);

  void attach(VoidCallback onChange) {
    _listener = onChange;
    qty.addListener(onChange);
    price.addListener(onChange);
  }

  void set(String n, String q, String p) {
    name.text = n;
    qty.text = q;
    price.text = p;
  }

  bool get isEmpty =>
      name.text.trim().isEmpty &&
      qty.text.trim().isEmpty &&
      price.text.trim().isEmpty;

  double get lineTotal {
    final q = double.tryParse(qty.text) ?? 0;
    final p = double.tryParse(price.text) ?? 0;
    return q * p;
  }

  void dispose() {
    if (_listener != null) {
      qty.removeListener(_listener!);
      price.removeListener(_listener!);
    }
    name.dispose();
    qty.dispose();
    price.dispose();
  }
}

// ── Picker sheets ─────────────────────────────────────────────────────────────

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();
  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();
  List<Product> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_search);
    _search();
  }

  Future<void> _search() async {
    final list = await _db.listProducts(query: _searchCtrl.text.trim());
    if (mounted) setState(() {
      _items = list;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, scroll) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Search catalog…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          message:
                              'No products yet.\nItems are saved automatically\nwhen you create invoices.')
                      : ListView.builder(
                          controller: scroll,
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final p = _items[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.brand.withOpacity(0.1),
                                child: Text(
                                    p.name.isNotEmpty
                                        ? p.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppTheme.brand)),
                              ),
                              title: Text(p.name),
                              subtitle: p.timesSold > 0
                                  ? Text('Sold ${p.timesSold}×')
                                  : null,
                              trailing: Text(money(p.price),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              onTap: () => Navigator.pop(context, p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends StatefulWidget {
  const _CustomerPickerSheet();
  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();
  List<Customer> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_search);
    _search();
  }

  Future<void> _search() async {
    final list = await _db.listCustomers(query: _searchCtrl.text.trim());
    if (mounted) setState(() {
      _items = list;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (_, scroll) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search customers…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const EmptyState(
                          icon: Icons.people_outline,
                          message: 'No saved customers yet.')
                      : ListView.builder(
                          controller: scroll,
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final c = _items[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.accent.withOpacity(0.15),
                                child: Text(
                                    c.name.isNotEmpty
                                        ? c.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppTheme.accent)),
                              ),
                              title: Text(c.name),
                              subtitle: Text([
                                if ((c.phone ?? '').isNotEmpty) c.phone!,
                                if (c.invoiceCount > 0)
                                  '${c.invoiceCount} invoices'
                              ].join('  •  ')),
                              trailing: c.totalSpent > 0
                                  ? Text(money(c.totalSpent),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))
                                  : null,
                              onTap: () => Navigator.pop(context, c),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
