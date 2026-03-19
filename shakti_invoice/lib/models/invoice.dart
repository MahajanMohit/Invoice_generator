import 'invoice_item.dart';

class Invoice {
  final int? id;
  final String invoiceNo;
  final String date;
  final String time;
  final String day;
  final String customer;
  final double grandTotal;
  final String paid;
  final double balance;
  final String? pdfPath;
  final String? createdAt;
  final List<InvoiceItem> items;

  Invoice({
    this.id,
    required this.invoiceNo,
    required this.date,
    required this.time,
    required this.day,
    required this.customer,
    required this.grandTotal,
    this.paid = 'Paid',
    this.balance = 0,
    this.pdfPath,
    this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() => {
        'invoice_no': invoiceNo,
        'date': date,
        'time': time,
        'day': day,
        'customer': customer,
        'grand_total': grandTotal,
        'paid': paid,
        'balance': balance,
        'pdf_path': pdfPath,
      };

  factory Invoice.fromMap(Map<String, dynamic> map, {List<InvoiceItem> items = const []}) =>
      Invoice(
        id: map['id'] as int?,
        invoiceNo: map['invoice_no'] as String,
        date: map['date'] as String,
        time: map['time'] as String,
        day: map['day'] as String,
        customer: map['customer'] as String,
        grandTotal: (map['grand_total'] as num).toDouble(),
        paid: map['paid'] as String? ?? 'Paid',
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        pdfPath: map['pdf_path'] as String?,
        createdAt: map['created_at'] as String?,
        items: items,
      );
}
