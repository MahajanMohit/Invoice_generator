class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final String itemName;
  final double qty;
  final double unitPrice;
  final double total;

  InvoiceItem({
    this.id,
    this.invoiceId,
    required this.itemName,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });

  Map<String, dynamic> toMap(int invoiceId) => {
        'invoice_id': invoiceId,
        'item_name': itemName,
        'qty': qty,
        'unit_price': unitPrice,
        'total': total,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
        id: map['id'] as int?,
        invoiceId: map['invoice_id'] as int?,
        itemName: map['item_name'] as String,
        qty: (map['qty'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        total: (map['total'] as num).toDouble(),
      );
}
