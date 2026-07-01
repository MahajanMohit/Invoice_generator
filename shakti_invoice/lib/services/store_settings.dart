import 'package:shared_preferences/shared_preferences.dart';

/// Holds all user-configurable store settings.
class StoreSettings {
  final String storeName;
  final String storeTagline;
  final String storeLocation;
  final String storePhone;
  final String footerLine1;
  final String footerLine2;

  // Billing configuration
  final String currencySymbol; // e.g. "Rs.", "₹", "$"
  final String invoicePrefix; // e.g. "IC"
  final double defaultTaxRate; // GST % applied by default (0 = none)
  final String taxLabel; // e.g. "GST", "VAT", "Tax"
  final String defaultPaymentMethod; // Cash | UPI | Card | Credit
  final int retentionDays; // auto-purge invoices older than this

  const StoreSettings({
    required this.storeName,
    required this.storeTagline,
    required this.storeLocation,
    required this.storePhone,
    required this.footerLine1,
    required this.footerLine2,
    required this.currencySymbol,
    required this.invoicePrefix,
    required this.defaultTaxRate,
    required this.taxLabel,
    required this.defaultPaymentMethod,
    required this.retentionDays,
  });

  factory StoreSettings.defaults() => const StoreSettings(
        storeName: 'My Store',
        storeTagline: 'Quality Products | Trusted Service',
        storeLocation: '',
        storePhone: '',
        footerLine1: 'Thank you for shopping with us!',
        footerLine2: '',
        currencySymbol: 'Rs.',
        invoicePrefix: 'IC',
        defaultTaxRate: 0,
        taxLabel: 'GST',
        defaultPaymentMethod: 'Cash',
        retentionDays: 30,
      );

  /// Full display name shown on receipts (name + location if set)
  String get displayName =>
      storeLocation.trim().isEmpty ? storeName : '$storeName, $storeLocation';

  StoreSettings copyWith({
    String? storeName,
    String? storeTagline,
    String? storeLocation,
    String? storePhone,
    String? footerLine1,
    String? footerLine2,
    String? currencySymbol,
    String? invoicePrefix,
    double? defaultTaxRate,
    String? taxLabel,
    String? defaultPaymentMethod,
    int? retentionDays,
  }) =>
      StoreSettings(
        storeName: storeName ?? this.storeName,
        storeTagline: storeTagline ?? this.storeTagline,
        storeLocation: storeLocation ?? this.storeLocation,
        storePhone: storePhone ?? this.storePhone,
        footerLine1: footerLine1 ?? this.footerLine1,
        footerLine2: footerLine2 ?? this.footerLine2,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
        taxLabel: taxLabel ?? this.taxLabel,
        defaultPaymentMethod: defaultPaymentMethod ?? this.defaultPaymentMethod,
        retentionDays: retentionDays ?? this.retentionDays,
      );
}

/// Service that loads and saves [StoreSettings] using SharedPreferences.
class StoreSettingsService {
  static const _kName = 'store_name';
  static const _kTagline = 'store_tagline';
  static const _kLocation = 'store_location';
  static const _kPhone = 'store_phone';
  static const _kFooter1 = 'store_footer1';
  static const _kFooter2 = 'store_footer2';
  static const _kCurrency = 'currency_symbol';
  static const _kPrefix = 'invoice_prefix';
  static const _kTaxRate = 'default_tax_rate';
  static const _kTaxLabel = 'tax_label';
  static const _kPayMethod = 'default_payment_method';
  static const _kRetention = 'retention_days';
  static const _kOnboarded = 'onboarding_complete';

  static Future<StoreSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final d = StoreSettings.defaults();
    return StoreSettings(
      storeName: prefs.getString(_kName) ?? d.storeName,
      storeTagline: prefs.getString(_kTagline) ?? d.storeTagline,
      storeLocation: prefs.getString(_kLocation) ?? d.storeLocation,
      storePhone: prefs.getString(_kPhone) ?? d.storePhone,
      footerLine1: prefs.getString(_kFooter1) ?? d.footerLine1,
      footerLine2: prefs.getString(_kFooter2) ?? d.footerLine2,
      currencySymbol: prefs.getString(_kCurrency) ?? d.currencySymbol,
      invoicePrefix: prefs.getString(_kPrefix) ?? d.invoicePrefix,
      defaultTaxRate: prefs.getDouble(_kTaxRate) ?? d.defaultTaxRate,
      taxLabel: prefs.getString(_kTaxLabel) ?? d.taxLabel,
      defaultPaymentMethod:
          prefs.getString(_kPayMethod) ?? d.defaultPaymentMethod,
      retentionDays: prefs.getInt(_kRetention) ?? d.retentionDays,
    );
  }

  static Future<void> save(StoreSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, s.storeName);
    await prefs.setString(_kTagline, s.storeTagline);
    await prefs.setString(_kLocation, s.storeLocation);
    await prefs.setString(_kPhone, s.storePhone);
    await prefs.setString(_kFooter1, s.footerLine1);
    await prefs.setString(_kFooter2, s.footerLine2);
    await prefs.setString(_kCurrency, s.currencySymbol);
    await prefs.setString(_kPrefix, s.invoicePrefix);
    await prefs.setDouble(_kTaxRate, s.defaultTaxRate);
    await prefs.setString(_kTaxLabel, s.taxLabel);
    await prefs.setString(_kPayMethod, s.defaultPaymentMethod);
    await prefs.setInt(_kRetention, s.retentionDays);
  }

  static Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboarded) ?? false;
  }

  static Future<void> setOnboarded(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarded, v);
  }
}
