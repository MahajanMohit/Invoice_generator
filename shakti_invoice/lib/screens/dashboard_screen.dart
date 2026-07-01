import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../database/database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseHelper();
  int _range = 7; // days
  bool _loading = true;

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _top = [];

  @override
  void initState() {
    super.initState();
    dataRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    dataRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final stats = await _db.overallStats();
    final sales = await _db.salesByDay(_range);
    final payments = await _db.paymentBreakdown(_range);
    final top = await _db.topProducts(limit: 5, days: _range);
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _sales = sales;
      _payments = payments;
      _top = top;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        automaticallyImplyLeading: false,
        title: const Text('Dashboard'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (_, mode, __) => IconButton(
              tooltip: mode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
              icon: Icon(mode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode),
              onPressed: () => themeModeNotifier.value =
                  mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _statGrid(),
                  const SizedBox(height: 20),
                  _rangeSelector(),
                  const SizedBox(height: 16),
                  _salesCard(),
                  const SizedBox(height: 16),
                  _paymentCard(),
                  const SizedBox(height: 16),
                  _topProductsCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _statGrid() {
    final revenue = (_stats['revenue'] as double?) ?? 0;
    final count = (_stats['invoiceCount'] as int?) ?? 0;
    final avg = (_stats['avgInvoice'] as double?) ?? 0;
    final unpaid = (_stats['unpaid'] as double?) ?? 0;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _StatCard(
            icon: Icons.account_balance_wallet,
            label: 'Total Revenue',
            value: money(revenue),
            color: AppTheme.brand),
        _StatCard(
            icon: Icons.receipt_long,
            label: 'Invoices',
            value: '$count',
            color: AppTheme.accent),
        _StatCard(
            icon: Icons.trending_up,
            label: 'Avg. Invoice',
            value: money(avg),
            color: AppTheme.success),
        _StatCard(
            icon: Icons.pending_actions,
            label: 'Outstanding',
            value: money(unpaid),
            color: unpaid > 0 ? AppTheme.danger : AppTheme.brandMid),
      ],
    );
  }

  Widget _rangeSelector() {
    Widget chip(int days, String label) {
      final sel = _range == days;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_range != days) {
              setState(() => _range = days);
              _load();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? AppTheme.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel
                      ? AppTheme.brand
                      : Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Text(label,
                style: TextStyle(
                    color: sel
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13)),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(7, 'Last 7 days'),
        chip(30, 'Last 30 days'),
        chip(90, 'Last 90 days'),
      ],
    );
  }

  Widget _salesCard() {
    final total =
        _sales.fold<double>(0, (s, r) => s + (r['total'] as double));
    final values = _sales.map((r) => r['total'] as double).toList();
    final labels = _sales.map((r) {
      final d = r['date'] as DateTime;
      return _range <= 7 ? DateFormat('E').format(d) : DateFormat('d').format(d);
    }).toList();
    final every = _range <= 7 ? 1 : (_range <= 30 ? 5 : 15);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(icon: Icons.show_chart, title: 'Sales Trend'),
            Text(money(total),
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary)),
            Text('in the last $_range days',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5))),
            const SizedBox(height: 12),
            if (values.every((v) => v == 0))
              _flatHint('No sales in this period')
            else
              BarChart(
                  values: values,
                  labels: labels,
                  color: AppTheme.brandMid,
                  labelEvery: every),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard() {
    final total =
        _payments.fold<double>(0, (s, r) => s + (r['total'] as double));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
                icon: Icons.pie_chart, title: 'Payment Methods'),
            if (total <= 0)
              _flatHint('No payments in this period')
            else
              Row(
                children: [
                  DonutChart(
                    size: 128,
                    thickness: 24,
                    values:
                        _payments.map((r) => r['total'] as double).toList(),
                    colors: AppTheme.chartPalette,
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(compact(total),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('total',
                            style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < _payments.length; i++)
                          _legendRow(
                            AppTheme
                                .chartPalette[i % AppTheme.chartPalette.length],
                            _payments[i]['method'] as String,
                            money(_payments[i]['total'] as double),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(Color c, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: c, borderRadius: BorderRadius.circular(3))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _topProductsCard() {
    final maxRev = _top.isEmpty
        ? 1.0
        : _top.map((r) => r['revenue'] as double).reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
                icon: Icons.workspace_premium, title: 'Top Products'),
            if (_top.isEmpty)
              _flatHint('No products sold yet')
            else
              for (int i = 0; i < _top.length; i++)
                _topRow(i, _top[i], maxRev),
          ],
        ),
      ),
    );
  }

  Widget _topRow(int i, Map<String, dynamic> p, double maxRev) {
    final cs = Theme.of(context).colorScheme;
    final rev = p['revenue'] as double;
    final color = AppTheme.chartPalette[i % AppTheme.chartPalette.length];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: Text('${i + 1}',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(p['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              Text(money(rev),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxRev <= 0 ? 0 : rev / maxRev,
              minHeight: 5,
              backgroundColor: cs.outlineVariant.withOpacity(0.35),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${qtyFmt(p['qty'] as double)} sold',
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flatHint(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(msg,
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }
}
