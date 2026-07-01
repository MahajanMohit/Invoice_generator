import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/product.dart';
import '../models/customer.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const int _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'invoices.db');
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ── Schema ────────────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE invoices (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no     TEXT    NOT NULL,
        date           TEXT    NOT NULL,
        time           TEXT    NOT NULL,
        day            TEXT    NOT NULL,
        customer       TEXT    NOT NULL,
        customer_phone TEXT,
        subtotal       REAL    NOT NULL DEFAULT 0,
        discount       REAL    NOT NULL DEFAULT 0,
        discount_type  TEXT    NOT NULL DEFAULT 'flat',
        discount_value REAL    NOT NULL DEFAULT 0,
        tax_rate       REAL    NOT NULL DEFAULT 0,
        tax_amount     REAL    NOT NULL DEFAULT 0,
        previous_balance REAL  NOT NULL DEFAULT 0,
        grand_total    REAL    NOT NULL,
        paid           TEXT    NOT NULL DEFAULT 'Paid',
        payment_method TEXT    NOT NULL DEFAULT 'Cash',
        balance        REAL    NOT NULL DEFAULT 0,
        notes          TEXT,
        pdf_path       TEXT,
        created_at     TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');
    await db.execute('''
      CREATE TABLE invoice_items (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id  INTEGER NOT NULL REFERENCES invoices(id),
        product_id  INTEGER,
        item_name   TEXT    NOT NULL,
        qty         REAL    NOT NULL,
        unit_price  REAL    NOT NULL,
        total       REAL    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE products (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        price      REAL    NOT NULL DEFAULT 0,
        category   TEXT,
        unit       TEXT,
        times_sold INTEGER NOT NULL DEFAULT 0,
        created_at TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');
    await db.execute('''
      CREATE TABLE customers (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        phone      TEXT,
        email      TEXT,
        address    TEXT,
        created_at TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');
    await _createIndices(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Extend invoices with money-breakdown + payment columns.
      const alters = <String>[
        "ALTER TABLE invoices ADD COLUMN customer_phone TEXT",
        "ALTER TABLE invoices ADD COLUMN subtotal REAL NOT NULL DEFAULT 0",
        "ALTER TABLE invoices ADD COLUMN discount REAL NOT NULL DEFAULT 0",
        "ALTER TABLE invoices ADD COLUMN discount_type TEXT NOT NULL DEFAULT 'flat'",
        "ALTER TABLE invoices ADD COLUMN discount_value REAL NOT NULL DEFAULT 0",
        "ALTER TABLE invoices ADD COLUMN tax_rate REAL NOT NULL DEFAULT 0",
        "ALTER TABLE invoices ADD COLUMN tax_amount REAL NOT NULL DEFAULT 0",
        "ALTER TABLE invoices ADD COLUMN previous_balance REAL NOT NULL DEFAULT 0",
        "ALTER TABLE invoices ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'Cash'",
        "ALTER TABLE invoices ADD COLUMN notes TEXT",
        "ALTER TABLE invoice_items ADD COLUMN product_id INTEGER",
      ];
      for (final sql in alters) {
        try {
          await db.execute(sql);
        } catch (_) {
          // Column may already exist on partially-migrated installs.
        }
      }
      // Backfill subtotal from grand_total for legacy rows.
      await db.execute(
          "UPDATE invoices SET subtotal = grand_total WHERE subtotal = 0");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          name       TEXT    NOT NULL,
          price      REAL    NOT NULL DEFAULT 0,
          category   TEXT,
          unit       TEXT,
          times_sold INTEGER NOT NULL DEFAULT 0,
          created_at TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          name       TEXT    NOT NULL,
          phone      TEXT,
          email      TEXT,
          address    TEXT,
          created_at TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
        )
      ''');
      await _createIndices(db);
      // Seed the customer directory from existing invoice history.
      await db.execute('''
        INSERT INTO customers (name)
        SELECT DISTINCT customer FROM invoices
        WHERE customer IS NOT NULL AND TRIM(customer) <> ''
      ''');
    }
  }

  Future<void> _createIndices(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_items_invoice ON invoice_items(invoice_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_created ON invoices(created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_invoices_customer ON invoices(customer)');
  }

  // ── Invoices ────────────────────────────────────────────────────────────────

  /// Returns next invoice number like PREFIX-001.
  Future<String> nextInvoiceNumber({String prefix = 'IC'}) async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(id) as max_id FROM invoices');
    final lastId = (result.first['max_id'] as int?) ?? 0;
    return '$prefix-${(lastId + 1).toString().padLeft(3, '0')}';
  }

  /// Insert invoice + items, returns the new invoice id.
  /// Also learns products into the catalog and records the customer.
  Future<int> insertInvoice(Invoice invoice, List<InvoiceItem> items) async {
    final db = await database;
    final id = await db.transaction((txn) async {
      final invoiceId = await txn.insert('invoices', invoice.toMap());
      for (final item in items) {
        await txn.insert('invoice_items', item.toMap(invoiceId));
      }
      await _learnFromInvoice(txn, invoice, items);
      return invoiceId;
    });
    return id;
  }

  /// Replace an existing invoice and its items (used by edit).
  /// Also refreshes catalog prices / customer info, but does NOT re-count
  /// the sale (that was already counted when the invoice was first created).
  Future<void> updateInvoice(Invoice invoice) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('invoices', invoice.toMap(),
          where: 'id = ?', whereArgs: [invoice.id]);
      await txn.delete('invoice_items',
          where: 'invoice_id = ?', whereArgs: [invoice.id]);
      for (final item in invoice.items) {
        await txn.insert('invoice_items', item.toMap(invoice.id!));
      }
      await _learnFromInvoice(txn, invoice, invoice.items,
          incrementSales: false);
    });
  }

  /// Auto-populate the catalog + customer directory from a saved invoice.
  /// [incrementSales] bumps each product's popularity counter; pass false when
  /// editing an existing invoice so the sale isn't double-counted (prices still
  /// get refreshed so the catalog stays consistent with the latest edit).
  Future<void> _learnFromInvoice(
      Transaction txn, Invoice invoice, List<InvoiceItem> items,
      {bool incrementSales = true}) async {
    // Customer directory
    final name = invoice.customer.trim();
    if (name.isNotEmpty) {
      final existing = await txn.query('customers',
          where: 'name = ? COLLATE NOCASE', whereArgs: [name], limit: 1);
      if (existing.isEmpty) {
        await txn.insert('customers', {
          'name': name,
          'phone': invoice.customerPhone,
        });
      } else if ((invoice.customerPhone ?? '').isNotEmpty &&
          (existing.first['phone'] == null ||
              (existing.first['phone'] as String).isEmpty)) {
        await txn.update('customers', {'phone': invoice.customerPhone},
            where: 'id = ?', whereArgs: [existing.first['id']]);
      }
    }
    // Product catalog — create unknown items, bump popularity for known ones.
    for (final item in items) {
      final itemName = item.itemName.trim();
      if (itemName.isEmpty || itemName == '(unnamed)') continue;
      final existing = await txn.query('products',
          where: 'name = ? COLLATE NOCASE', whereArgs: [itemName], limit: 1);
      if (existing.isEmpty) {
        await txn.insert('products', {
          'name': itemName,
          'price': item.unitPrice,
          'times_sold': incrementSales ? 1 : 0,
        });
      } else {
        final id = existing.first['id'] as int;
        final sold = (existing.first['times_sold'] as int?) ?? 0;
        await txn.update(
            'products',
            {
              // Keep catalog price fresh with the latest used price — on both
              // new invoices and edits.
              'price': item.unitPrice,
              if (incrementSales) 'times_sold': sold + 1,
            },
            where: 'id = ?',
            whereArgs: [id]);
      }
    }
  }

  Future<void> updatePdfPath(int invoiceId, String pdfPath) async {
    final db = await database;
    await db.update('invoices', {'pdf_path': pdfPath},
        where: 'id = ?', whereArgs: [invoiceId]);
  }

  Future<void> markInvoicePaid(int invoiceId) async {
    final db = await database;
    await db.update('invoices', {'paid': 'Paid', 'balance': 0},
        where: 'id = ?', whereArgs: [invoiceId]);
  }

  Future<void> deleteInvoice(int invoiceId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn
          .delete('invoice_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);
      await txn.delete('invoices', where: 'id = ?', whereArgs: [invoiceId]);
    });
  }

  Future<List<Invoice>> listInvoices() async {
    final db = await database;
    final rows = await db.query('invoices', orderBy: 'id DESC');
    return rows.map((r) => Invoice.fromMap(r)).toList();
  }

  Future<List<Invoice>> listTodayInvoices() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT * FROM invoices WHERE date(created_at) = date('now','localtime') ORDER BY id DESC",
    );
    return rows.map((r) => Invoice.fromMap(r)).toList();
  }

  Future<List<Invoice>> listInvoicesForDays(int days) async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT * FROM invoices WHERE created_at >= datetime('now','localtime','-$days days') ORDER BY id DESC",
    );
    return rows.map((r) => Invoice.fromMap(r)).toList();
  }

  Future<int> deleteOldInvoices(int keepDays) async {
    final db = await database;
    return db.transaction((txn) async {
      final oldRows = await txn.rawQuery(
        "SELECT id FROM invoices WHERE created_at < datetime('now','localtime','-$keepDays days')",
      );
      if (oldRows.isEmpty) return 0;
      final ids = oldRows.map((r) => r['id'] as int).toList();
      final placeholders = List.filled(ids.length, '?').join(',');
      await txn.delete('invoice_items',
          where: 'invoice_id IN ($placeholders)', whereArgs: ids);
      return txn.delete('invoices',
          where: 'id IN ($placeholders)', whereArgs: ids);
    });
  }

  Future<Map<String, dynamic>> getTodaySummary() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count, COALESCE(SUM(grand_total), 0.0) as total "
      "FROM invoices WHERE date(created_at) = date('now','localtime')",
    );
    return {
      'count': result.first['count'] as int,
      'total': (result.first['total'] as num).toDouble(),
    };
  }

  Future<Invoice?> getInvoice(String invoiceNo) async {
    final db = await database;
    final invRows = await db.query('invoices',
        where: 'invoice_no = ?',
        whereArgs: [invoiceNo],
        orderBy: 'id DESC',
        limit: 1);
    if (invRows.isEmpty) return null;
    return _hydrate(db, invRows.first);
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final db = await database;
    final invRows =
        await db.query('invoices', where: 'id = ?', whereArgs: [id], limit: 1);
    if (invRows.isEmpty) return null;
    return _hydrate(db, invRows.first);
  }

  Future<Invoice> _hydrate(Database db, Map<String, dynamic> row) async {
    final itemRows = await db.query('invoice_items',
        where: 'invoice_id = ?', whereArgs: [row['id']]);
    final items = itemRows.map(InvoiceItem.fromMap).toList();
    return Invoice.fromMap(row, items: items);
  }

  // ── Analytics ───────────────────────────────────────────────────────────────

  /// Overall lifetime + outstanding stats for the dashboard header.
  Future<Map<String, dynamic>> overallStats() async {
    final db = await database;
    final rev = await db.rawQuery(
        "SELECT COUNT(*) c, COALESCE(SUM(grand_total),0) t FROM invoices");
    final unpaid = await db.rawQuery(
        "SELECT COALESCE(SUM(balance),0) b FROM invoices WHERE paid <> 'Paid'");
    final custs =
        await db.rawQuery("SELECT COUNT(*) c FROM customers");
    final count = rev.first['c'] as int;
    final total = (rev.first['t'] as num).toDouble();
    return {
      'invoiceCount': count,
      'revenue': total,
      'avgInvoice': count == 0 ? 0.0 : total / count,
      'unpaid': (unpaid.first['b'] as num).toDouble(),
      'customers': custs.first['c'] as int,
    };
  }

  /// Daily totals for the last [days] days (oldest → newest, gaps filled).
  Future<List<Map<String, dynamic>>> salesByDay(int days) async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT date(created_at) d, COALESCE(SUM(grand_total),0) t, COUNT(*) c "
      "FROM invoices WHERE created_at >= datetime('now','localtime','-${days - 1} days') "
      "GROUP BY date(created_at)",
    );
    final byDate = {for (final r in rows) r['d'] as String: r};
    final today = DateTime.now();
    final out = <Map<String, dynamic>>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final r = byDate[key];
      out.add({
        'date': day,
        'total': r == null ? 0.0 : (r['t'] as num).toDouble(),
        'count': r == null ? 0 : r['c'] as int,
      });
    }
    return out;
  }

  /// Top-selling products by revenue within the last [days] days.
  Future<List<Map<String, dynamic>>> topProducts(
      {int limit = 5, int days = 30}) async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT ii.item_name name, SUM(ii.qty) qty, SUM(ii.total) revenue "
      "FROM invoice_items ii JOIN invoices i ON ii.invoice_id = i.id "
      "WHERE i.created_at >= datetime('now','localtime','-$days days') "
      "GROUP BY ii.item_name COLLATE NOCASE "
      "ORDER BY revenue DESC LIMIT $limit",
    );
    return rows
        .map((r) => {
              'name': r['name'] as String,
              'qty': (r['qty'] as num).toDouble(),
              'revenue': (r['revenue'] as num).toDouble(),
            })
        .toList();
  }

  /// Revenue split by payment method within the last [days] days.
  Future<List<Map<String, dynamic>>> paymentBreakdown(int days) async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT payment_method m, COALESCE(SUM(grand_total),0) t, COUNT(*) c "
      "FROM invoices WHERE created_at >= datetime('now','localtime','-$days days') "
      "GROUP BY payment_method ORDER BY t DESC",
    );
    return rows
        .map((r) => {
              'method': (r['m'] as String?) ?? 'Cash',
              'total': (r['t'] as num).toDouble(),
              'count': r['c'] as int,
            })
        .toList();
  }

  // ── Products ────────────────────────────────────────────────────────────────

  Future<List<Product>> listProducts({String query = ''}) async {
    final db = await database;
    final rows = query.isEmpty
        ? await db.query('products',
            orderBy: 'times_sold DESC, name COLLATE NOCASE')
        : await db.query('products',
            where: 'name LIKE ?',
            whereArgs: ['%$query%'],
            orderBy: 'times_sold DESC, name COLLATE NOCASE');
    return rows.map(Product.fromMap).toList();
  }

  /// Autocomplete suggestions for the invoice item field.
  Future<List<Product>> suggestProducts(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await database;
    final rows = await db.query('products',
        where: 'name LIKE ?',
        whereArgs: ['%${query.trim()}%'],
        orderBy: 'times_sold DESC, name COLLATE NOCASE',
        limit: 6);
    return rows.map(Product.fromMap).toList();
  }

  Future<int> saveProduct(Product p) async {
    final db = await database;
    if (p.id == null) {
      return db.insert('products', p.toMap());
    }
    await db
        .update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
    return p.id!;
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ── Customers ───────────────────────────────────────────────────────────────

  /// Customers with lifetime aggregates (invoice count, spend, last visit).
  Future<List<Customer>> listCustomers({String query = ''}) async {
    final db = await database;
    final where = query.isEmpty
        ? ''
        : "WHERE c.name LIKE '%$query%' OR c.phone LIKE '%$query%'";
    final rows = await db.rawQuery('''
      SELECT c.*,
             COUNT(i.id) AS invoice_count,
             COALESCE(SUM(i.grand_total), 0) AS total_spent,
             MAX(i.created_at) AS last_visit
      FROM customers c
      LEFT JOIN invoices i ON i.customer = c.name COLLATE NOCASE
      $where
      GROUP BY c.id
      ORDER BY total_spent DESC, c.name COLLATE NOCASE
    ''');
    return rows.map(Customer.fromMap).toList();
  }

  Future<List<Customer>> suggestCustomers(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await database;
    final rows = await db.query('customers',
        where: 'name LIKE ? OR phone LIKE ?',
        whereArgs: ['%${query.trim()}%', '%${query.trim()}%'],
        orderBy: 'name COLLATE NOCASE',
        limit: 6);
    return rows.map(Customer.fromMap).toList();
  }

  Future<int> saveCustomer(Customer c) async {
    final db = await database;
    if (c.id == null) {
      return db.insert('customers', c.toMap());
    }
    await db
        .update('customers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    return c.id!;
  }

  Future<void> deleteCustomer(int id) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  /// Total unpaid balance across a customer's earlier invoices.
  /// Pass [excludeInvoiceId] when editing so the invoice doesn't count itself.
  Future<double> customerOutstanding(String name,
      {int? excludeInvoiceId}) async {
    final db = await database;
    final extra = excludeInvoiceId != null ? 'AND id <> $excludeInvoiceId' : '';
    final rows = await db.rawQuery(
      "SELECT COALESCE(SUM(balance),0) b FROM invoices "
      "WHERE customer = ? COLLATE NOCASE AND paid <> 'Paid' $extra",
      [name],
    );
    return (rows.first['b'] as num).toDouble();
  }

  /// All invoices for a given customer name (for the customer detail view).
  Future<List<Invoice>> invoicesForCustomer(String name) async {
    final db = await database;
    final rows = await db.query('invoices',
        where: 'customer = ? COLLATE NOCASE',
        whereArgs: [name],
        orderBy: 'id DESC');
    return rows.map((r) => Invoice.fromMap(r)).toList();
  }

  // ── Backup / Restore ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    final invoiceRows = await db.query('invoices', orderBy: 'id ASC');
    final List<Map<String, dynamic>> out = [];
    for (final inv in invoiceRows) {
      final itemRows = await db.query('invoice_items',
          where: 'invoice_id = ?', whereArgs: [inv['id']]);
      out.add({...inv, 'items': itemRows.toList()});
    }
    final products = await db.query('products', orderBy: 'id ASC');
    final customers = await db.query('customers', orderBy: 'id ASC');
    return {
      'version': _dbVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'invoices': out,
      'products': products,
      'customers': customers,
    };
  }

  Future<void> importData(Map<String, dynamic> backup) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('invoice_items');
      await txn.delete('invoices');
      await txn.delete('products');
      await txn.delete('customers');

      final invoices = (backup['invoices'] as List<dynamic>?) ?? [];
      for (final invData in invoices) {
        final inv = Map<String, dynamic>.from(invData as Map);
        final items = (inv.remove('items') as List<dynamic>?) ?? [];
        inv.remove('id');
        final newId = await txn.insert('invoices', inv);
        for (final itemData in items) {
          final item = Map<String, dynamic>.from(itemData as Map);
          item.remove('id');
          item['invoice_id'] = newId;
          await txn.insert('invoice_items', item);
        }
      }
      for (final p in (backup['products'] as List<dynamic>?) ?? []) {
        final map = Map<String, dynamic>.from(p as Map)..remove('id');
        await txn.insert('products', map);
      }
      for (final c in (backup['customers'] as List<dynamic>?) ?? []) {
        final map = Map<String, dynamic>.from(c as Map)..remove('id');
        await txn.insert('customers', map);
      }

      // Legacy (v1) backups have no customers table — seed from invoices.
      if (backup['customers'] == null) {
        await txn.execute('''
          INSERT INTO customers (name)
          SELECT DISTINCT customer FROM invoices
          WHERE customer IS NOT NULL AND TRIM(customer) <> ''
        ''');
      }
    });
  }
}
