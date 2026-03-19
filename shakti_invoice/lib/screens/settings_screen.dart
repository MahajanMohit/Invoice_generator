import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../services/store_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _primary = Color(0xFF1a237e);
  static const Color _mid = Color(0xFF3949ab);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _footer1Ctrl = TextEditingController();
  final _footer2Ctrl = TextEditingController();

  final _db = DatabaseHelper();
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
    _nameCtrl.dispose();
    _taglineCtrl.dispose();
    _locationCtrl.dispose();
    _footer1Ctrl.dispose();
    _footer2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await StoreSettingsService.load();
    if (mounted) {
      _nameCtrl.text = s.storeName;
      _taglineCtrl.text = s.storeTagline;
      _locationCtrl.text = s.storeLocation;
      _footer1Ctrl.text = s.footerLine1;
      _footer2Ctrl.text = s.footerLine2;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await StoreSettingsService.save(StoreSettings(
      storeName: _nameCtrl.text.trim(),
      storeTagline: _taglineCtrl.text.trim(),
      storeLocation: _locationCtrl.text.trim(),
      footerLine1: _footer1Ctrl.text.trim(),
      footerLine2: _footer2Ctrl.text.trim(),
    ));
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Settings saved!'),
        backgroundColor: Color(0xFF2e7d32),
      ));
      // Return true so HomeScreen knows to reload
      Navigator.pop(context, true);
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to defaults?'),
        content: const Text('This will restore the example store name and messages.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    final d = StoreSettings.defaults();
    _nameCtrl.text = d.storeName;
    _taglineCtrl.text = d.storeTagline;
    _locationCtrl.text = d.storeLocation;
    _footer1Ctrl.text = d.footerLine1;
    _footer2Ctrl.text = d.footerLine2;
    setState(() {});
  }

  Future<void> _backup() async {
    setState(() => _backingUp = true);
    try {
      final data = await _db.exportAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final name =
          'shakti_bills_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      final file = File('${dir.path}/$name');
      await file.writeAsString(jsonStr);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Shakti Bills Backup – $name',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e'),
              backgroundColor: const Color(0xFFe53935)),
        );
      }
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
            'All current invoice data will be replaced with the backup file. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _restoring = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _restoring = false);
        return;
      }
      final content = await File(result.files.single.path!).readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      if (data['version'] == null || data['invoices'] == null) {
        throw const FormatException('Not a valid Shakti Bills backup file.');
      }
      await _db.importData(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Backup restored successfully!'),
          backgroundColor: Color(0xFF2e7d32),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e'),
              backgroundColor: const Color(0xFFe53935)),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
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
        title: const Text('Store Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.restart_alt, color: Colors.white70, size: 18),
            label: const Text('Reset', style: TextStyle(color: Colors.white70)),
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionHeader(Icons.store, 'Store Identity', cs),
                  const SizedBox(height: 10),
                  _field(
                    controller: _nameCtrl,
                    label: 'Store Name',
                    hint: 'e.g. My General Store',
                    required: true,
                    maxLength: 60,
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _locationCtrl,
                    label: 'Location / City',
                    hint: 'e.g. Dablehar  (optional)',
                    required: false,
                    maxLength: 60,
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _taglineCtrl,
                    label: 'Tagline',
                    hint: 'e.g. Quality Products | Trusted Service',
                    required: false,
                    maxLength: 80,
                    cs: cs,
                  ),
                  const SizedBox(height: 24),
                  _sectionHeader(Icons.receipt_long, 'Receipt Footer', cs),
                  const SizedBox(height: 4),
                  Text(
                    'These lines appear at the bottom of every printed receipt.',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.55)),
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _footer1Ctrl,
                    label: 'Footer Line 1',
                    hint: 'e.g. Thank you for shopping with us!',
                    required: false,
                    maxLength: 80,
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _footer2Ctrl,
                    label: 'Footer Line 2',
                    hint: 'e.g. Visit us again!  (optional)',
                    required: false,
                    maxLength: 80,
                    cs: cs,
                  ),
                  const SizedBox(height: 24),
                  _buildPreview(cs),
                  const SizedBox(height: 24),
                  _sectionHeader(Icons.backup, 'Data Management', cs),
                  const SizedBox(height: 4),
                  Text(
                    'Backup exports all invoices as a JSON file you can save or share. '
                    'Restore replaces all data from a previous backup.',
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurface.withOpacity(0.55)),
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
                              : const Icon(Icons.upload),
                          label:
                              Text(_backingUp ? 'Exporting…' : 'Backup Data'),
                          onPressed:
                              (_backingUp || _restoring) ? null : _backup,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: cs.primary),
                            foregroundColor: cs.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
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
                          label: Text(
                              _restoring ? 'Restoring…' : 'Restore Backup'),
                          onPressed:
                              (_backingUp || _restoring) ? null : _restore,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side:
                                BorderSide(color: cs.error.withOpacity(0.7)),
                            foregroundColor: cs.error,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save Settings'),
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, ColorScheme cs) => Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: cs.primary)),
        ],
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool required,
    required int maxLength,
    required ColorScheme cs,
  }) =>
      TextFormField(
        controller: controller,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.primary, width: 2),
          ),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      );

  /// Live preview of how the receipt header/footer will look
  Widget _buildPreview(ColorScheme cs) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_nameCtrl, _taglineCtrl, _locationCtrl, _footer1Ctrl, _footer2Ctrl]),
      builder: (_, __) {
        final name = _nameCtrl.text.trim();
        final location = _locationCtrl.text.trim();
        final tagline = _taglineCtrl.text.trim();
        final f1 = _footer1Ctrl.text.trim();
        final f2 = _footer2Ctrl.text.trim();
        final displayName = location.isEmpty ? name : '$name, $location';
        final dividerColor = cs.outline.withOpacity(0.35);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.visibility, 'Receipt Preview', cs),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outline.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    displayName.isEmpty ? '(Store Name)' : displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: cs.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (tagline.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(tagline,
                        style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: cs.primary.withOpacity(0.75)),
                        textAlign: TextAlign.center),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: dividerColor),
                  ),
                  Text('RECEIPT',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.6))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: dividerColor),
                  ),
                  Text('... invoice items ...',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.35))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: dividerColor),
                  ),
                  if (f1.isNotEmpty)
                    Text(f1,
                        style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: cs.onSurface.withOpacity(0.55)),
                        textAlign: TextAlign.center),
                  if (f2.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(f2,
                        style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: cs.onSurface.withOpacity(0.55)),
                        textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
