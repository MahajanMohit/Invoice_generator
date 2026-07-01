import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/store_settings.dart';
import '../theme/app_theme.dart';
import 'root_nav.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  final _nameCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'Rs.');
  int _index = 0;
  bool _saving = false;

  @override
  void dispose() {
    _page.dispose();
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final base = StoreSettings.defaults();
    final s = base.copyWith(
      storeName: _nameCtrl.text.trim().isEmpty
          ? 'My Store'
          : _nameCtrl.text.trim(),
      currencySymbol:
          _currencyCtrl.text.trim().isEmpty ? 'Rs.' : _currencyCtrl.text.trim(),
    );
    await StoreSettingsService.save(s);
    await StoreSettingsService.setOnboarded(true);
    currencyNotifier.value = s.currencySymbol;
    if (mounted) {
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RootNav()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _page,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _slide(
                      icon: Icons.receipt_long,
                      title: 'Welcome to Invoice Bills',
                      body:
                          'Create professional GST invoices & thermal receipts in seconds — fully offline.',
                    ),
                    _slide(
                      icon: Icons.insights,
                      title: 'Know your business',
                      body:
                          'A live dashboard tracks sales trends, top products, payments and outstanding dues.',
                    ),
                    _setupSlide(),
                  ],
                ),
              ),
              _dots(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.brand),
                    onPressed: _saving
                        ? null
                        : () {
                            if (_index < 2) {
                              _page.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut);
                            } else {
                              _finish();
                            }
                          },
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Text(_index < 2 ? 'Next' : 'Get Started'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slide(
          {required IconData icon,
          required String title,
          required String body}) =>
      Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 96, color: Colors.white),
            const SizedBox(height: 32),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
          ],
        ),
      );

  Widget _setupSlide() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.storefront, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            const Text('Set up your store',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _whiteField(_nameCtrl, 'Store name', 'e.g. Sharma General Store'),
            const SizedBox(height: 14),
            _whiteField(_currencyCtrl, 'Currency symbol', 'Rs.  /  ₹  /  \$'),
            const SizedBox(height: 8),
            const Text('You can change everything later in Settings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      );

  Widget _whiteField(TextEditingController c, String label, String hint) =>
      TextField(
        controller: c,
        style: const TextStyle(color: Colors.white),
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.white),
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withOpacity(0.12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white38),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white, width: 1.6),
          ),
        ),
      );

  Widget _dots() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          3,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _index == i ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _index == i ? Colors.white : Colors.white38,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );
}
