import 'package:intl/intl.dart';
import '../app_state.dart';

final NumberFormat _money = NumberFormat('#,##0.00');
final NumberFormat _compact = NumberFormat.compact();

/// "Rs. 1,234.50" — uses the globally selected currency symbol.
String money(double v) => '${currencyNotifier.value} ${_money.format(v)}';

/// "1,234.50" — amount only, no symbol.
String amount(double v) => _money.format(v);

/// "1.2K", "3.4L"-style compact number for dashboard tiles.
String compact(num v) => _compact.format(v);

/// Quantity: whole number if integer, otherwise up to 2 decimals.
String qtyFmt(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Parse "dd-MM-yyyy" (the format stored in the DB) into a DateTime.
DateTime? parseDbDate(String date) {
  final parts = date.split('-');
  if (parts.length != 3) return null;
  final d = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final y = int.tryParse(parts[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y, m, d);
}
