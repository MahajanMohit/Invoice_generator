import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../app_state.dart';
import '../database/database_helper.dart';
import '../services/store_settings.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();

  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _footer1Ctrl = TextEditingController();
  final _footer2Ctrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  final _taxLabelCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();
  final _retentionCtrl = TextEditingController();

  String _payMethod = 'Cash';
  bool _loading = true;
  bool _saving = false;
  bool _backingUp = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _taglineCtrl,
      _locationCtrl,
      _phoneCtrl,
      _footer1Ctrl,
      _footer2Ctrl,
      _currencyCtrl,
      _prefixCtrl,
      _taxLabelCtrl,
      _taxRateCtrl,
      _retentionCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = await StoreSettingsService.load();
    _nameCtrl.text = s.storeName;
    _taglineCtrl.text = s.storeTagline;
    _locationCtrl.text = s.storeLocation;
    _phoneCtrl.text = s.storePhone;
    _footer1Ctrl.text = s.footerLine1;
    _footer2Ctrl.text = s.footerLine2;
    _currencyCtrl.text = s.currencySymbol;
    _prefixCtrl.text = s.invoicePrefix;
    _taxLabelCtrl.text = s.taxLabel;
    _taxRateCtrl.text = s.defaultTaxRate > 0 ? s.defaultTaxRate.toString() : '';
    _retentionCtrl.text = s.retentionDays.toString();
    _payMethod = s.defaultPaymentMethod;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final s = StoreSettings(
      storeName: _nameCtrl.text.trim(),
      storeTagline: _taglineCtrl.text.trim(),
      storeLocation: _locationCtrl.text.trim(),
      storePhone: _phoneCtrl.text.trim(),
      footerLine1: _footer1Ctrl.text.trim(),
      footerLine2: _footer2Ctrl.text.trim(),
      currencySymbol: _currencyCtrl.text.trim().isEmpty
          ? 'Rs.'
          : _currencyCtrl.text.trim(),
      invoicePrefix:
          _prefixCtrl.text.trim().isEmpty ? 'IC' : _prefixCtrl.text.trim(),
      taxLabel:
          _taxLabelCtrl.text.trim().isEmpty ? 'GST' : _taxLabelCtrl.text.trim(),
      defaultTaxRate: double.tryParse(_taxRateCtrl.text) ?? 0,
      defaultPaymentMethod: _payMethod,
      retentionDays: int.tryParse(_retentionCtrl.text) ?? 30,
    );
    await StoreSettingsService.save(s);
    currencyNotifier.value = s.currencySymbol;
    if (mounted) {
      setState(() => _saving = false);
      _snack('Settings saved!');
      Navigator.pop(context, true);
    }
  }

  Future<void> _backup() async {
    setState(() => _backingUp = true);
    try {
      final data = await _db.exportAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final name =
          'invoice_bills_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      final file = File('${dir.path}/$name');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')],
          subject: 'Invoice Bills Backup',
          text: 'Choose Google Drive to store this backup in the cloud.');
    } catch (e) {
      _snack('Backup failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
            'All current data will be replaced with the backup file. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Restore', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _restoring = true);
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['json']);
      if (result == null || result.files.isEmpty) {
        setState(() => _restoring = false);
        return;
      }
      final content = await File(result.files.single.path!).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      if (data['version'] == null || data['invoices'] == null) {
        throw const FormatException('Not a valid Invoice Bills backup file.');
      }
      await _db.importData(data);
      pingData();
      _snack('Backup restored successfully!');
    } catch (e) {
      _snack('Restore failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _snack(String m, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: error ? Colors.red : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SectionHeader(icon: Icons.store, title: 'Store Identity'),
                  _field(_nameCtrl, 'Store Name', required: true),
                  _field(_locationCtrl, 'Location / City'),
                  _field(_phoneCtrl, 'Phone', keyboard: TextInputType.phone),
                  _field(_taglineCtrl, 'Tagline'),
                  const SizedBox(height: 20),
                  const SectionHeader(
                      icon: Icons.tune, title: 'Billing Preferences'),
                  Row(
                    children: [
                      Expanded(
                          child: _field(_currencyCtrl, 'Currency',
                              inline: true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _field(_prefixCtrl, 'Invoice Prefix',
                              inline: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _field(_taxLabelCtrl, 'Tax Label',
                              inline: true)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _field(_taxRateCtrl, 'Default Tax %',
                              inline: true, number: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _payMethod,
                    decoration:
                        const InputDecoration(labelText: 'Default Payment'),
                    items: const ['Cash', 'UPI', 'Card', 'Credit']
                        .map((m) =>
                            DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (v) => setState(() => _payMethod = v ?? 'Cash'),
                  ),
                  const SizedBox(height: 12),
                  _field(_retentionCtrl, 'Keep invoices for (days)',
                      number: true),
                  const SizedBox(height: 20),
                  const SectionHeader(
                      icon: Icons.receipt_long, title: 'Receipt Footer'),
                  _field(_footer1Ctrl, 'Footer Line 1'),
                  _field(_footer2Ctrl, 'Footer Line 2'),
                  const SizedBox(height: 20),
                  const SectionHeader(
                      icon: Icons.cloud_upload, title: 'Backup & Google Drive'),
                  Text(
                    'Backup saves everything (invoices, products, customers) as one file. '
                    'On the share sheet, pick Google Drive to keep it safely in the cloud — '
                    'or save it anywhere. Restore loads a backup file back in.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: _backingUp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.cloud_upload_outlined),
                          label:
                              Text(_backingUp ? 'Exporting…' : 'Back up to Drive'),
                          onPressed:
                              (_backingUp || _restoring) ? null : _backup,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: _restoring
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.download),
                          label: Text(_restoring ? 'Restoring…' : 'Restore'),
                          onPressed:
                              (_backingUp || _restoring) ? null : _restore,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade400),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving…' : 'Save Settings'),
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    bool inline = false,
    bool number = false,
    TextInputType? keyboard,
  }) {
    final field = TextFormField(
      controller: c,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : keyboard,
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      textCapitalization:
          number ? TextCapitalization.none : TextCapitalization.words,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '$label required' : null
          : null,
    );
    return inline
        ? field
        : Padding(padding: const EdgeInsets.only(top: 12), child: field);
  }
}
