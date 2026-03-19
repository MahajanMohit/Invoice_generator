import 'package:shared_preferences/shared_preferences.dart';

/// Holds all user-configurable store settings.
class StoreSettings {
  final String storeName;
  final String storeTagline;
  final String storeLocation;
  final String footerLine1;
  final String footerLine2;

  const StoreSettings({
    required this.storeName,
    required this.storeTagline,
    required this.storeLocation,
    required this.footerLine1,
    required this.footerLine2,
  });

  /// Factory with defaults (used on first launch)
  factory StoreSettings.defaults() => const StoreSettings(
        storeName: 'My Store',
        storeTagline: 'Quality Products | Trusted Service',
        storeLocation: '',
        footerLine1: 'Thank you for shopping with us!',
        footerLine2: '',
      );

  /// Full display name shown on receipts (name + location if set)
  String get displayName =>
      storeLocation.trim().isEmpty ? storeName : '$storeName, $storeLocation';
}

/// Service that loads and saves [StoreSettings] using SharedPreferences.
class StoreSettingsService {
  static const _kName = 'store_name';
  static const _kTagline = 'store_tagline';
  static const _kLocation = 'store_location';
  static const _kFooter1 = 'store_footer1';
  static const _kFooter2 = 'store_footer2';

  static Future<StoreSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = StoreSettings.defaults();
    return StoreSettings(
      storeName: prefs.getString(_kName) ?? defaults.storeName,
      storeTagline: prefs.getString(_kTagline) ?? defaults.storeTagline,
      storeLocation: prefs.getString(_kLocation) ?? defaults.storeLocation,
      footerLine1: prefs.getString(_kFooter1) ?? defaults.footerLine1,
      footerLine2: prefs.getString(_kFooter2) ?? defaults.footerLine2,
    );
  }

  static Future<void> save(StoreSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, s.storeName);
    await prefs.setString(_kTagline, s.storeTagline);
    await prefs.setString(_kLocation, s.storeLocation);
    await prefs.setString(_kFooter1, s.footerLine1);
    await prefs.setString(_kFooter2, s.footerLine2);
  }
}
