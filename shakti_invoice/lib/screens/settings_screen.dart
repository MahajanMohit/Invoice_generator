import 'package:flutter/material.dart';
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

  bool _loading = true;
  bool _saving = false;

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
                  _sectionHeader(Icons.store, 'Store Identity'),
                  const SizedBox(height: 10),
                  _field(
                    controller: _nameCtrl,
                    label: 'Store Name',
                    hint: 'e.g. My General Store',
                    required: true,
                    maxLength: 60,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _locationCtrl,
                    label: 'Location / City',
                    hint: 'e.g. Dablehar  (optional)',
                    required: false,
                    maxLength: 60,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _taglineCtrl,
                    label: 'Tagline',
                    hint: 'e.g. Quality Products | Trusted Service',
                    required: false,
                    maxLength: 80,
                  ),
                  const SizedBox(height: 24),
                  _sectionHeader(Icons.receipt_long, 'Receipt Footer'),
                  const SizedBox(height: 4),
                  Text(
                    'These lines appear at the bottom of every printed receipt.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  _field(
                    controller: _footer1Ctrl,
                    label: 'Footer Line 1',
                    hint: 'e.g. Thank you for shopping with us!',
                    required: false,
                    maxLength: 80,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _footer2Ctrl,
                    label: 'Footer Line 2',
                    hint: 'e.g. Visit us again!  (optional)',
                    required: false,
                    maxLength: 80,
                  ),
                  const SizedBox(height: 24),
                  _buildPreview(),
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

  Widget _sectionHeader(IconData icon, String title) => Row(
        children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _primary)),
        ],
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool required,
    required int maxLength,
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
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      );

  /// Live preview of how the receipt header/footer will look
  Widget _buildPreview() {
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.visibility, 'Receipt Preview'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFc5cae9)),
              ),
              child: Column(
                children: [
                  Text(
                    displayName.isEmpty ? '(Store Name)' : displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (tagline.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(tagline,
                        style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: _mid),
                        textAlign: TextAlign.center),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFFc5cae9)),
                  ),
                  const Text('RECEIPT',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: _mid)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFFc5cae9)),
                  ),
                  const Text('... invoice items ...',
                      style: TextStyle(fontSize: 11, color: Colors.black38)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: Color(0xFFc5cae9)),
                  ),
                  if (f1.isNotEmpty)
                    Text(f1,
                        style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.black54),
                        textAlign: TextAlign.center),
                  if (f2.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(f2,
                        style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Colors.black54),
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
