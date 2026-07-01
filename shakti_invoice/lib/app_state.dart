import 'package:flutter/material.dart';

/// Global, app-wide reactive state.
///
/// Kept intentionally tiny — just the handful of values that many
/// widgets need to react to without threading them through constructors.

/// Light / dark theme. Persisted in [main] via SharedPreferences.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

/// Currency symbol shown in front of every amount (e.g. "Rs.", "₹", "$").
final currencyNotifier = ValueNotifier<String>('Rs.');

/// Bumped whenever invoices/products/customers change so open screens
/// (dashboard, history) can refresh themselves. Increment via [pingData].
final dataRevision = ValueNotifier<int>(0);

void pingData() => dataRevision.value++;
