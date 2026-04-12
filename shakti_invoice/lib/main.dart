import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

const _kDarkModeKey = 'theme_dark';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  themeModeNotifier.value =
      (prefs.getBool(_kDarkModeKey) ?? false) ? ThemeMode.dark : ThemeMode.light;
  themeModeNotifier.addListener(() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDarkModeKey, themeModeNotifier.value == ThemeMode.dark);
  });
  runApp(const InvoiceCreatorApp());
}

class InvoiceCreatorApp extends StatelessWidget {
  const InvoiceCreatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Invoice Bills',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1a237e),
            primary: const Color(0xFF1a237e),
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1a237e),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
