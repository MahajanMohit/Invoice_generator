import 'invoice_item.dart';

class Invoice {
  final int? id;
  final String invoiceNo;
  final String date;
  final String time;
  final String day;
  final String customer;
  final String? customerPhone;

  // Money breakdown
  final double subtotal; // sum of line totals before discount/tax
  final double discount; // absolute discount amount (already resolved)
  final String discountType; // 'flat' or 'percent'
  final double discountValue; // the raw value entered (₹ or %)
  final double taxRate; // percentage, e.g. 18 for 18% GST
  final double taxAmount; // absolute tax amount
  final double previousBalance; // old dues carried forward from before
  final double grandTotal; // subtotal - discount + tax + previousBalance

  // Payment
  final String paid; // 'Paid' | 'Unpaid' | 'Partial'
  final String paymentMethod; // 'Cash' | 'UPI' | 'Card' | 'Credit'
  final double balance; // outstanding amount

  final String? notes;
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
    this.customerPhone,
    this.subtotal = 0,
    this.discount = 0,
    this.discountType = 'flat',
    this.discountValue = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    this.previousBalance = 0,
    required this.grandTotal,
    this.paid = 'Paid',
    this.paymentMethod = 'Cash',
    this.balance = 0,
    this.notes,
    this.pdfPath,
    this.createdAt,
    this.items = const [],
  });

  bool get isPaid => paid == 'Paid';

  Map<String, dynamic> toMap() => {
        'invoice_no': invoiceNo,
        'date': date,
        'time': time,
        'day': day,
        'customer': customer,
        'customer_phone': customerPhone,
        'subtotal': subtotal,
        'discount': discount,
        'discount_type': discountType,
        'discount_value': discountValue,
        'tax_rate': taxRate,
        'tax_amount': taxAmount,
        'previous_balance': previousBalance,
        'grand_total': grandTotal,
        'paid': paid,
        'payment_method': paymentMethod,
        'balance': balance,
        'notes': notes,
        'pdf_path': pdfPath,
      };

  factory Invoice.fromMap(Map<String, dynamic> map,
          {List<InvoiceItem> items = const []}) =>
      Invoice(
        id: map['id'] as int?,
        invoiceNo: map['invoice_no'] as String,
        date: map['date'] as String,
        time: map['time'] as String,
        day: map['day'] as String,
        customer: map['customer'] as String,
        customerPhone: map['customer_phone'] as String?,
        subtotal: (map['subtotal'] as num?)?.toDouble() ??
            (map['grand_total'] as num).toDouble(),
        discount: (map['discount'] as num?)?.toDouble() ?? 0,
        discountType: map['discount_type'] as String? ?? 'flat',
        discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0,
        taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0,
        taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
        previousBalance: (map['previous_balance'] as num?)?.toDouble() ?? 0,
        grandTotal: (map['grand_total'] as num).toDouble(),
        paid: map['paid'] as String? ?? 'Paid',
        paymentMethod: map['payment_method'] as String? ?? 'Cash',
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        notes: map['notes'] as String?,
        pdfPath: map['pdf_path'] as String?,
        createdAt: map['created_at'] as String?,
        items: items,
      );

  Invoice copyWith({
    int? id,
    String? invoiceNo,
    String? paid,
    double? balance,
    String? pdfPath,
  }) =>
      Invoice(
        id: id ?? this.id,
        invoiceNo: invoiceNo ?? this.invoiceNo,
        date: date,
        time: time,
        day: day,
        customer: customer,
        customerPhone: customerPhone,
        subtotal: subtotal,
        discount: discount,
        discountType: discountType,
        discountValue: discountValue,
        taxRate: taxRate,
        taxAmount: taxAmount,
        previousBalance: previousBalance,
        grandTotal: grandTotal,
        paid: paid ?? this.paid,
        paymentMethod: paymentMethod,
        balance: balance ?? this.balance,
        notes: notes,
        pdfPath: pdfPath ?? this.pdfPath,
        createdAt: createdAt,
        items: items,
      );
}
