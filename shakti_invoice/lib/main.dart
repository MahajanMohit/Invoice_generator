import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';
import 'services/store_settings.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/root_nav.dart';

const _kDarkModeKey = 'theme_dark';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Restore persisted theme.
  themeModeNotifier.value =
      (prefs.getBool(_kDarkModeKey) ?? false) ? ThemeMode.dark : ThemeMode.light;
  themeModeNotifier.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDarkModeKey, themeModeNotifier.value == ThemeMode.dark);
  });

  // Restore currency symbol so amounts format correctly everywhere.
  final settings = await StoreSettingsService.load();
  currencyNotifier.value = settings.currencySymbol;

  final onboarded = await StoreSettingsService.isOnboarded();

  runApp(InvoiceBillsApp(onboarded: onboarded));
}

class InvoiceBillsApp extends StatelessWidget {
  final bool onboarded;
  const InvoiceBillsApp({super.key, required this.onboarded});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) => ValueListenableBuilder<String>(
        valueListenable: currencyNotifier,
        builder: (_, __, ___) => MaterialApp(
          title: 'Invoice Bills',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: onboarded ? const RootNav() : const OnboardingScreen(),
        ),
      ),
    );
  }
}
