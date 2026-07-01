import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../app_state.dart';
import '../database/database_helper.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();
  List<Customer> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_load);
    dataRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    dataRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _db.listCustomers(query: _searchCtrl.text.trim());
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  Future<void> _edit([Customer? c]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _CustomerEditor(customer: c),
    );
    if (saved == true) {
      _load();
      pingData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        automaticallyImplyLeading: false,
        title: const Text('Customers'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Customer'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search customers…',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_outline,
                        message:
                            'No customers yet.\nThey are added automatically when you\nbill them, or add one manually.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) => _tile(_items[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Customer c) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accent.withOpacity(0.15),
          child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppTheme.accent, fontWeight: FontWeight.bold)),
        ),
        title: Text(c.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          if ((c.phone ?? '').isNotEmpty) c.phone!,
          '${c.invoiceCount} invoice${c.invoiceCount == 1 ? '' : 's'}',
        ].join('  •  ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(c.totalSpent),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: cs.primary)),
            const Text('lifetime', style: TextStyle(fontSize: 10)),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => _CustomerDetailScreen(customer: c)),
        ).then((_) => _load()),
      ),
    );
  }
}

class _CustomerEditor extends StatefulWidget {
  final Customer? customer;
  const _CustomerEditor({this.customer});

  @override
  State<_CustomerEditor> createState() => _CustomerEditorState();
}

class _CustomerEditorState extends State<_CustomerEditor> {
  final _db = DatabaseHelper();
  late final _name = TextEditingController(text: widget.customer?.name ?? '');
  late final _phone = TextEditingController(text: widget.customer?.phone ?? '');
  late final _email = TextEditingController(text: widget.customer?.email ?? '');
  late final _address =
      TextEditingController(text: widget.customer?.address ?? '');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await _db.saveCustomer(Customer(
      id: widget.customer?.id,
      name: name,
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
    ));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.customer == null ? 'Add Customer' : 'Edit Customer',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            decoration:
                const InputDecoration(labelText: 'Address (optional)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const _CustomerDetailScreen({required this.customer});

  @override
  State<_CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<_CustomerDetailScreen> {
  final _db = DatabaseHelper();
  List<Invoice> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _db.invoicesForCustomer(widget.customer.name);
    if (mounted) {
      setState(() {
        _invoices = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.customer;
    final total = _invoices.fold<double>(0, (s, i) => s + i.grandTotal);
    return Scaffold(
      appBar: GradientAppBar(title: Text(c.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((c.phone ?? '').isNotEmpty)
                          _infoRow(Icons.phone, c.phone!),
                        if ((c.email ?? '').isNotEmpty)
                          _infoRow(Icons.email, c.email!),
                        if ((c.address ?? '').isNotEmpty)
                          _infoRow(Icons.location_on, c.address!),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat('Invoices', '${_invoices.length}', cs),
                            _stat('Lifetime', money(total), cs),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SectionHeader(
                    icon: Icons.history, title: 'Purchase History'),
                if (_invoices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No invoices yet.')),
                  )
                else
                  ..._invoices.map((inv) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(inv.invoiceNo),
                          subtitle: Text('${inv.date}  •  ${inv.paymentMethod}'),
                          trailing: Text(money(inv.grandTotal),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          onTap: inv.pdfPath != null
                              ? () => OpenFilex.open(inv.pdfPath!)
                              : null,
                        ),
                      )),
              ],
            ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.brandMid),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );

  Widget _stat(String label, String value, ColorScheme cs) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.primary)),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
        ],
      );
}
