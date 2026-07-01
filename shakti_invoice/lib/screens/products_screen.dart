import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _db = DatabaseHelper();
  final _searchCtrl = TextEditingController();
  List<Product> _items = [];
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
    final list = await _db.listProducts(query: _searchCtrl.text.trim());
    if (mounted) {
      setState(() {
        _items = list;
        _loading = false;
      });
    }
  }

  Future<void> _edit([Product? p]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _ProductEditor(product: p),
    );
    if (saved == true) {
      _load();
      pingData();
    }
  }

  Future<void> _delete(Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('"${p.name}" will be removed from your catalog.'),
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
      await _db.deleteProduct(p.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        automaticallyImplyLeading: false,
        title: const Text('Catalog'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search products…',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        message:
                            'No products yet.\nProducts are saved automatically as you\nbill them, or add them manually.',
                        action: FilledButton.icon(
                          onPressed: () => _edit(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Product'),
                        ),
                      )
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

  Widget _tile(Product p) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.brand.withOpacity(0.1),
          child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppTheme.brand)),
        ),
        title: Text(p.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          if ((p.category ?? '').isNotEmpty) p.category!,
          if (p.timesSold > 0) 'Sold ${p.timesSold}×',
        ].join('  •  ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(money(p.price),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: cs.primary)),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? _edit(p) : _delete(p),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        onTap: () => _edit(p),
      ),
    );
  }
}

class _ProductEditor extends StatefulWidget {
  final Product? product;
  const _ProductEditor({this.product});

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _db = DatabaseHelper();
  late final TextEditingController _name =
      TextEditingController(text: widget.product?.name ?? '');
  late final TextEditingController _price = TextEditingController(
      text: widget.product != null
          ? widget.product!.price.toStringAsFixed(2)
          : '');
  late final TextEditingController _category =
      TextEditingController(text: widget.product?.category ?? '');
  late final TextEditingController _unit =
      TextEditingController(text: widget.product?.unit ?? '');

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _category.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final p = Product(
      id: widget.product?.id,
      name: name,
      price: double.tryParse(_price.text) ?? 0,
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      timesSold: widget.product?.timesSold ?? 0,
    );
    await _db.saveProduct(p);
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
          Text(widget.product == null ? 'Add Product' : 'Edit Product',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Product name'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unit,
                  decoration: const InputDecoration(
                      labelText: 'Unit', hintText: 'pc, kg…'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _category,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(labelText: 'Category (optional)'),
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
