/// Pure invoice math shared by the create screen, editor and PDF service.
class Totals {
  final double subtotal;
  final double discount;
  final double taxable;
  final double tax;
  final double previousBalance;
  final double grandTotal;

  const Totals({
    required this.subtotal,
    required this.discount,
    required this.taxable,
    required this.tax,
    required this.previousBalance,
    required this.grandTotal,
  });
}

Totals computeTotals({
  required double subtotal,
  required String discountType, // 'flat' | 'percent'
  required double discountValue,
  required double taxRate, // percentage
  double previousBalance = 0, // old dues carried forward
}) {
  final rawDiscount = discountType == 'percent'
      ? subtotal * discountValue / 100.0
      : discountValue;
  final discount = rawDiscount.clamp(0.0, subtotal).toDouble();
  final taxable = subtotal - discount;
  final tax = taxable * taxRate / 100.0;
  final prev = previousBalance < 0 ? 0.0 : previousBalance;
  final grand = taxable + tax + prev;
  return Totals(
    subtotal: _r(subtotal),
    discount: _r(discount),
    taxable: _r(taxable),
    tax: _r(tax),
    previousBalance: _r(prev),
    grandTotal: _r(grand),
  );
}

double _r(double v) => double.parse(v.toStringAsFixed(2));
