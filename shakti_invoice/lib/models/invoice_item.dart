class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final int? productId; // optional link to catalog product
  final String itemName;
  final double qty;
  final double unitPrice;
  final double total;

  InvoiceItem({
    this.id,
    this.invoiceId,
    this.productId,
    required this.itemName,
    required this.qty,
    required this.unitPrice,
    required this.total,
  });

  Map<String, dynamic> toMap(int invoiceId) => {
        'invoice_id': invoiceId,
        'product_id': productId,
        'item_name': itemName,
        'qty': qty,
        'unit_price': unitPrice,
        'total': total,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
        id: map['id'] as int?,
        invoiceId: map['invoice_id'] as int?,
        productId: map['product_id'] as int?,
        itemName: map['item_name'] as String,
        qty: (map['qty'] as num).toDouble(),
        unitPrice: (map['unit_price'] as num).toDouble(),
        total: (map['total'] as num).toDouble(),
      );
}
