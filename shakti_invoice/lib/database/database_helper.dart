import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/invoice.dart';
import '../models/invoice_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

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
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no  TEXT    NOT NULL,
        date        TEXT    NOT NULL,
        time        TEXT    NOT NULL,
        day         TEXT    NOT NULL,
        customer    TEXT    NOT NULL,
        grand_total REAL    NOT NULL,
        paid        TEXT    NOT NULL DEFAULT 'Paid',
        balance     REAL    NOT NULL DEFAULT 0,
        pdf_path    TEXT,
        created_at  TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS invoice_items (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id  INTEGER NOT NULL REFERENCES invoices(id),
        item_name   TEXT    NOT NULL,
        qty         REAL    NOT NULL,
        unit_price  REAL    NOT NULL,
        total       REAL    NOT NULL
      )
    ''');
  }

  /// Returns next invoice number like IC-001
  Future<String> nextInvoiceNumber() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(id) as max_id FROM invoices');
    final lastId = (result.first['max_id'] as int?) ?? 0;
    return 'IC-${(lastId + 1).toString().padLeft(3, '0')}';
  }

  /// Insert invoice + items, returns the new invoice id
  Future<int> insertInvoice(Invoice invoice, List<InvoiceItem> items) async {
    final db = await database;
    return db.transaction((txn) async {
      final invoiceId = await txn.insert('invoices', invoice.toMap());
      for (final item in items) {
        await txn.insert('invoice_items', item.toMap(invoiceId));
      }
      return invoiceId;
    });
  }

  /// Update the pdf_path after PDF generation
  Future<void> updatePdfPath(int invoiceId, String pdfPath) async {
    final db = await database;
    await db.update(
      'invoices',
      {'pdf_path': pdfPath},
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  /// List all invoices (newest first), without items
  Future<List<Invoice>> listInvoices() async {
    final db = await database;
    final rows = await db.query('invoices', orderBy: 'id DESC');
    return rows.map((r) => Invoice.fromMap(r)).toList();
  }

  /// List invoices created today (device local time)
  Future<List<Invoice>> listTodayInvoices() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT * FROM invoices WHERE date(created_at) = date('now','localtime') ORDER BY id DESC",
    );
    return rows.map((r) => Invoice.fromMap(r)).toList();
  }

  /// List invoices from the last [days] days (inclusive)
  Future<List<Invoice>> listInvoicesForDays(int days) async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT * FROM invoices WHERE created_at >= datetime('now','localtime','-$days days') ORDER BY id DESC",
    );
    return rows.map((r) => Invoice.fromMap(r)).toList();
  }

  /// Delete invoices (and their items) older than [keepDays] days.
  /// Returns the number of invoice rows deleted.
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

  /// Returns today's invoice count and grand total sum
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

  /// Export every invoice + its items as a JSON-serialisable map
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    final invoiceRows = await db.query('invoices', orderBy: 'id ASC');
    final List<Map<String, dynamic>> out = [];
    for (final inv in invoiceRows) {
      final itemRows = await db.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [inv['id']],
      );
      out.add({...inv, 'items': itemRows.toList()});
    }
    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'invoices': out,
    };
  }

  /// Wipe all data and replace with the contents of [backup].
  /// The backup map must come from [exportAllData].
  Future<void> importData(Map<String, dynamic> backup) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('invoice_items');
      await txn.delete('invoices');
      final invoices = backup['invoices'] as List<dynamic>;
      for (final invData in invoices) {
        final inv = Map<String, dynamic>.from(invData as Map);
        final items = inv.remove('items') as List<dynamic>;
        inv.remove('id'); // let SQLite assign a new id
        final newId = await txn.insert('invoices', inv);
        for (final itemData in items) {
          final item = Map<String, dynamic>.from(itemData as Map);
          item.remove('id');
          item['invoice_id'] = newId;
          await txn.insert('invoice_items', item);
        }
      }
    });
  }

  /// Get a single invoice with its items
  Future<Invoice?> getInvoice(String invoiceNo) async {
    final db = await database;
    final invRows = await db.query(
      'invoices',
      where: 'invoice_no = ?',
      whereArgs: [invoiceNo],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (invRows.isEmpty) return null;
    final inv = invRows.first;
    final itemRows = await db.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [inv['id']],
    );
    final items = itemRows.map(InvoiceItem.fromMap).toList();
    return Invoice.fromMap(inv, items: items);
  }
}
