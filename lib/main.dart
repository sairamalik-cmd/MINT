import 'dart:math' as math;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'rates.dart';
import 'theme.dart';

void main() => runApp(const MintApp());

class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.rateId,
    required this.above,
    required this.target,
    this.triggered = false,
    this.enabled = true,
  });

  final String id;
  final String rateId;
  final bool above;
  final double target;
  final bool triggered;
  final bool enabled;

  PriceAlert copyWith({bool? triggered, bool? enabled}) => PriceAlert(
    id: id,
    rateId: rateId,
    above: above,
    target: target,
    triggered: triggered ?? this.triggered,
    enabled: enabled ?? this.enabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'rateId': rateId,
    'above': above,
    'target': target,
    'triggered': triggered,
    'enabled': enabled,
  };

  factory PriceAlert.fromJson(Map<String, dynamic> json) => PriceAlert(
    id: json['id'] as String,
    rateId: json['rateId'] as String,
    above: json['above'] as bool,
    target: (json['target'] as num).toDouble(),
    triggered: json['triggered'] as bool? ?? false,
    enabled: json['enabled'] as bool? ?? true,
  );
}

class MintApp extends StatelessWidget {
  const MintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MINT',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  final RateController _controller = RateController();
  List<Rate> _rates = placeholderRates;
  int _tab = 0;
  String _selected = 'gold';
  String _range = '1W';
  final Set<String> _favorites = {'gold', 'usd'};
  List<PriceAlert> _alerts = const [];

  Rate get selectedRate => _rates.firstWhere((rate) => rate.id == _selected);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onRatesChanged);
    _controller.start();
    _loadAlerts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onRatesChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.setForeground(state == AppLifecycleState.resumed);
  }

  void _onRatesChanged() {
    if (!mounted) return;
    setState(() {
      _rates = buildRates(
        snapshot: _controller.snapshot,
        history: _controller.history,
      );
    });
    _evaluateAlerts();
  }

  Future<void> _refresh() => _controller.refreshManual();

  void _openPurchaseCalculator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => PurchaseCalculatorSheet(gold: _rates.first),
    );
  }

  void _openAlertSuggestions() {
    final gold = _rates.first;
    final current = gold.amount;
    if (current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for the live gold price.')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suggested gold alerts', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.upBackground,
                child: Icon(Icons.trending_up, color: AppColors.upText),
              ),
              title: const Text('A 1.5% upward move'),
              subtitle: Text(
                'Above Rs ${formatPkr(current * 1.015, decimals: 0)}',
              ),
              trailing: const Icon(Icons.add_circle_outline),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() {
                  _alerts = [
                    ..._alerts,
                    PriceAlert(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      rateId: 'gold',
                      above: true,
                      target: current * 1.015,
                    ),
                  ];
                });
                _saveAlerts();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppColors.downBackground,
                child: Icon(Icons.trending_down, color: AppColors.downText),
              ),
              title: const Text('A 1.5% dip'),
              subtitle: Text(
                'Below Rs ${formatPkr(current * .985, decimals: 0)}',
              ),
              trailing: const Icon(Icons.add_circle_outline),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() {
                  _alerts = [
                    ..._alerts,
                    PriceAlert(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      rateId: 'gold',
                      above: false,
                      target: current * .985,
                    ),
                  ];
                });
                _saveAlerts();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openAlertSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => AlertFormSheet(
        rates: _rates,
        onSave: (alert) {
          setState(() => _alerts = [..._alerts, alert]);
          _saveAlerts();
        },
      ),
    );
  }

  Future<void> _loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mint.alerts.v1');
    if (!mounted || raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List;
      setState(() {
        _alerts = decoded
            .map((item) => PriceAlert.fromJson(item as Map<String, dynamic>))
            .toList();
      });
      _evaluateAlerts();
    } catch (_) {
      // Ignore an invalid old alert cache and let the user create new alerts.
    }
  }

  Future<void> _saveAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'mint.alerts.v1',
      jsonEncode(_alerts.map((alert) => alert.toJson()).toList()),
    );
  }

  void _evaluateAlerts() {
    var changed = false;
    final next = _alerts.map((alert) {
      final matches = _rates.where((item) => item.id == alert.rateId);
      final rate = matches.isEmpty ? null : matches.first;
      final amount = rate?.amount;
      if (!alert.enabled || alert.triggered || amount == null) return alert;
      final reached = alert.above
          ? amount >= alert.target
          : amount <= alert.target;
      if (!reached) return alert;
      changed = true;
      return alert.copyWith(triggered: true);
    }).toList();
    if (changed && mounted) {
      setState(() => _alerts = next);
      _saveAlerts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: IndexedStack(
              index: _tab,
              children: [
                _overview(),
                _ratesPage(),
                _historyPage(),
                _alertsPage(),
                _advisorPage(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.wallet_outlined),
              selectedIcon: Icon(Icons.wallet_rounded),
              label: 'Rates',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart_rounded),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_none_rounded),
              label: 'Alerts',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Advisor',
            ),
          ],
        ),
      ),
    );
  }

  Widget _page({required Widget child}) {
    return Column(
      children: [
        AppHeader(
          isRefreshing: _controller.isRefreshing,
          onRefresh: _refresh,
          onNotifications: _openAlertSheet,
        ),
        if (_controller.error != null)
          _StatusBanner(message: _controller.error!),
        Expanded(child: child),
      ],
    );
  }

  Widget _overview() {
    final gold = _rates.first;
    return _page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _DateGreeting(),
          const SizedBox(height: 16),
          LiveIndicator(updatedAt: gold.updatedAt, isStale: gold.isStale),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0B514C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gold 24K · per tola',
                  style: AppTextStyles.subtitle.copyWith(
                    color: const Color(0xFFDDEBE6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  gold.value,
                  style: AppTextStyles.hero.copyWith(
                    color: Colors.white,
                    fontSize: 38,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(36)),
                  ),
                  child: Text(
                    '${gold.isUp ? '▲' : '▼'} ${gold.change} today',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          EnhancedRateChart(
            rate: gold,
            values: _controller.chartValues(gold.id, _range),
            range: _range,
            onRangeChanged: _setRange,
          ),
          const SizedBox(height: 18),
          _buildAiInsight(gold),
          const SizedBox(height: 24),
          const SectionHeader(title: "Today's rates", label: 'PKR'),
          const SizedBox(height: 4),
          ..._rates.map(_rateRow),
          const SizedBox(height: 20),
          Text(
            'Gold is the international spot price converted to PKR. '
            'Currency rates by ExchangeRate-API. Reference prices only; '
            'local market rates may differ.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _ratesPage() {
    return _page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text('Rates', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 5),
          Text(
            'Live market prices in Pakistani Rupees',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Gold', label: 'PKR'),
          _rateRow(_rates[0]),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Currencies', label: 'PKR'),
          ..._rates.skip(1).map(_rateRow),
        ],
      ),
    );
  }

  Widget _historyPage() {
    final past = _pastValues(selectedRate);
    return _page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text('History', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 5),
          Text(
            'A clearer view of where rates have been.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 20),
          _selector(),
          const SizedBox(height: 20),
          EnhancedRateChart(
            rate: selectedRate,
            values: _controller.chartValues(selectedRate.id, _range),
            range: _range,
            onRangeChanged: _setRange,
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Past values', label: 'Recent'),
          if (past.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Past values will appear here as MINT records each day.',
                style: AppTextStyles.subtitle,
              ),
            ),
          ...past.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Expanded(child: Text(item.$1, style: AppTextStyles.subtitle)),
                  Text(item.$2, style: AppTextStyles.rowTitle),
                  const SizedBox(width: 14),
                  ChangePill(change: item.$3, isUp: item.$4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertsPage() {
    final active = _alerts.where((alert) => !alert.triggered).toList();
    final triggered = _alerts.where((alert) => alert.triggered).toList();
    return _page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text('Alerts', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 5),
          Text(
            'Know when a rate reaches your target.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 20),
          if (active.isEmpty) _emptyAlerts() else ...active.map(_alertCard),
          if (triggered.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Triggered', label: 'Past alerts'),
            const SizedBox(height: 12),
            ...triggered.map(
              (alert) => Opacity(opacity: .48, child: _alertCard(alert)),
            ),
          ],
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: _openAlertSheet,
            icon: const Icon(Icons.add),
            label: const Text('Create alert'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.teal,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.teal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _advisorPage() {
    final gold = _rates.first;
    final values = _controller.chartValues(gold.id, '1M');
    final avg = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a + b) / values.length;
    final high = values.isEmpty ? 0.0 : values.reduce(math.max);
    final low = values.isEmpty ? 0.0 : values.reduce(math.min);
    final usd = _rates.firstWhere(
      (rate) => rate.id == 'usd',
      orElse: () => _rates.first,
    );

    return _page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text('MINT Advisor', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 5),
          Text(
            'Explainable insights from live rates and your history.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 20),
          _advisorCard(
            icon: Icons.auto_awesome,
            title: 'Market summary',
            body: values.length < 2
                ? 'MINT is collecting enough history to explain market movement.'
                : 'Gold is ${gold.amount != null && gold.amount! >= avg ? 'above' : 'below'} its 30-day average. '
                      'Recent range: Rs ${formatPkr(low, decimals: 0)}–Rs ${formatPkr(high, decimals: 0)} per tola.',
            action: 'View gold history',
            onAction: () => setState(() {
              _selected = 'gold';
              _tab = 2;
            }),
          ),
          const SizedBox(height: 12),
          _advisorCard(
            icon: Icons.shopping_basket_outlined,
            title: 'Gold purchase calculator',
            body: 'Estimate 24K, 22K and 18K value before visiting a jeweller.',
            action: 'Calculate purchase',
            onAction: _openPurchaseCalculator,
          ),
          const SizedBox(height: 12),
          _advisorCard(
            icon: Icons.currency_exchange,
            title: 'Currency guidance',
            body:
                '${usd.name}: ${usd.change == '—' ? 'Waiting for a comparison' : '${usd.change} today'}. '
                'Exchange-rate movement can affect the PKR gold price.',
            action: 'Open rates',
            onAction: () => setState(() => _tab = 1),
          ),
          const SizedBox(height: 12),
          _advisorCard(
            icon: Icons.notifications_active_outlined,
            title: 'Suggested alerts',
            body: gold.amount == null
                ? 'Waiting for the live gold price.'
                : 'Watch for gold above Rs ${formatPkr(gold.amount! * 1.015, decimals: 0)} or below Rs ${formatPkr(gold.amount! * .985, decimals: 0)}.',
            action: 'Create suggested alert',
            onAction: _openAlertSuggestions,
          ),
          const SizedBox(height: 18),
          Text(
            'Advisor suggestions use your live and historical market data. '
            'They are not guaranteed outcomes or personal financial advice.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _advisorCard({
    required IconData icon,
    required String title,
    required String body,
    required String action,
    required VoidCallback onAction,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.mint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.teal, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: AppTextStyles.rowTitle)),
              ],
            ),
            const SizedBox(height: 12),
            Text(body, style: AppTextStyles.subtitle),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.teal,
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertCard(PriceAlert alert) {
    final rate = _rates.firstWhere(
      (item) => item.id == alert.rateId,
      orElse: () => _rates.first,
    );
    final current = rate.amount ?? 0;
    final progress = alert.above
        ? (current / alert.target).clamp(0.0, 1.0)
        : (alert.target == 0
              ? 0.0
              : (1 - current / alert.target).clamp(0.0, 1.0));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AlertCard(
        title:
            '${rate.name} goes ${alert.above ? 'above' : 'below'} Rs ${formatPkr(alert.target, decimals: rate.isGold ? 0 : 2)}',
        progress: progress,
        enabled: alert.enabled,
        isGold: rate.isGold,
        onChanged: (enabled) {
          setState(() {
            _alerts = _alerts
                .map(
                  (item) => item.id == alert.id
                      ? item.copyWith(enabled: enabled)
                      : item,
                )
                .toList();
          });
          _saveAlerts();
        },
      ),
    );
  }

  Widget _emptyAlerts() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 38,
            color: AppColors.teal,
          ),
          const SizedBox(height: 10),
          Text('No alerts yet', style: AppTextStyles.rowTitle),
          const SizedBox(height: 4),
          Text(
            'Create one to monitor a target price.',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildAiInsight(Rate gold) {
    final values = _controller.chartValues(gold.id, '1W');
    final change = values.length < 2
        ? null
        : (values.last - values.first) / values.first * 100;
    final title = change == null
        ? 'AI insight is learning the market'
        : change < -1
        ? 'Consider a small, staged buy'
        : change > 1
        ? 'Consider waiting for a pullback'
        : 'Hold and compare before buying';
    final detail = change == null
        ? 'MINT needs more live history before making a useful suggestion.'
        : 'Gold moved ${change.abs().toStringAsFixed(2)}% over the selected period. '
              'This is a trend signal, not financial advice.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MINT AI guide',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(title, style: AppTextStyles.rowTitle),
                  const SizedBox(height: 4),
                  Text(detail, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String>(
        segments: _rates
            .map(
              (rate) => ButtonSegment(value: rate.id, label: Text(rate.code)),
            )
            .toList(),
        selected: {_selected},
        onSelectionChanged: (value) => setState(() => _selected = value.first),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.divider),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.teal
                : AppColors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.secondary,
          ),
        ),
      ),
    );
  }

  Widget _rateRow(Rate rate) {
    return RateRow(
      rate: rate,
      favorite: _favorites.contains(rate.id),
      onFavorite: () => setState(
        () => _favorites.contains(rate.id)
            ? _favorites.remove(rate.id)
            : _favorites.add(rate.id),
      ),
      onTap: () => setState(() {
        _selected = rate.id;
        _tab = 2;
      }),
    );
  }

  void _setRange(String range) => setState(() => _range = range);

  /// Real daily closes recorded by the app, newest first.
  List<(String, String, String, bool)> _pastValues(Rate rate) {
    final closes = _controller.dailyCloses(rate.id);
    final now = DateTime.now();
    final decimals = rate.isGold ? 0 : 2;
    final rows = <(String, String, String, bool)>[];
    for (var i = closes.length - 1; i >= 0 && rows.length < 6; i--) {
      final close = closes[i];
      final previous = i > 0 ? closes[i - 1].value : null;
      final pct = previous == null || previous == 0
          ? null
          : (close.value - previous) / previous * 100;
      rows.add((
        dayLabel(close.date, now),
        'Rs ${formatPkr(close.value, decimals: decimals)}',
        pct == null ? '—' : '${pct.abs().toStringAsFixed(2)}%',
        pct == null || pct >= 0,
      ));
    }
    return rows;
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.goldTint,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Text(message, style: AppTextStyles.caption),
    );
  }
}

class MintLogo extends StatelessWidget {
  const MintLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.mint, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F5C58),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(painter: _MintLogoPainter()),
    );
  }
}

class _MintLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final mark = Paint()
      ..color = AppColors.teal
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final base = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .24, size.height * .68),
      Offset(size.width * .24, size.height * .32),
      mark,
    );
    canvas.drawLine(
      Offset(size.width * .24, size.height * .32),
      Offset(size.width * .50, size.height * .58),
      mark,
    );
    canvas.drawLine(
      Offset(size.width * .50, size.height * .58),
      Offset(size.width * .76, size.height * .32),
      mark,
    );
    canvas.drawLine(
      Offset(size.width * .76, size.height * .32),
      Offset(size.width * .76, size.height * .68),
      mark,
    );
    canvas.drawLine(
      Offset(size.width * .38, size.height * .76),
      Offset(size.width * .62, size.height * .76),
      base,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.isRefreshing,
    required this.onRefresh,
    required this.onNotifications,
    super.key,
  });

  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const MintLogo(),
          const SizedBox(width: 9),
          Text(
            'MINT',
            style: GoogleFonts.inter(
              color: AppColors.teal,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onNotifications,
            tooltip: 'Notifications',
            icon: const Badge(
              smallSize: 7,
              backgroundColor: AppColors.down,
              child: Icon(Icons.notifications_none_rounded),
            ),
          ),
          IconButton(
            onPressed: isRefreshing ? null : onRefresh,
            tooltip: 'Refresh rates',
            icon: isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _DateGreeting extends StatelessWidget {
  _DateGreeting();

  final DateTime now = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLine(now).toUpperCase(),
          style: GoogleFonts.inter(
            color: AppColors.secondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${greeting(now)}.',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Here’s what’s moving in your market today.',
          style: AppTextStyles.subtitle,
        ),
      ],
    );
  }
}

class LiveIndicator extends StatelessWidget {
  const LiveIndicator({this.updatedAt, this.isStale = false, super.key});

  final DateTime? updatedAt;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isStale ? AppColors.amber : AppColors.up,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          updatedAt == null
              ? 'Waiting for first update'
              : 'Updated ${timeAgo(updatedAt!, DateTime.now())}',
          style: AppTextStyles.caption,
        ),
        const Spacer(),
        const Icon(
          Icons.location_on_outlined,
          size: 15,
          color: AppColors.secondary,
        ),
        const SizedBox(width: 4),
        Text('Pakistan · PKR', style: AppTextStyles.caption),
      ],
    );
  }
}

class ChangePill extends StatelessWidget {
  const ChangePill({
    required this.change,
    required this.isUp,
    this.label,
    super.key,
  });

  final String change;
  final bool isUp;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final neutral = change == '—';
    final foreground = neutral
        ? AppColors.secondary
        : (isUp ? AppColors.upText : AppColors.downText);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: neutral
            ? AppColors.mint
            : (isUp ? AppColors.upBackground : AppColors.downBackground),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${neutral ? '' : (isUp ? '▲ ' : '▼ ')}$change${label == null ? '' : ' $label'}',
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.label, super.key});

  final String title;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.sectionTitle),
        const Spacer(),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}

class RateRow extends StatelessWidget {
  const RateRow({
    required this.rate,
    required this.favorite,
    required this.onFavorite,
    required this.onTap,
    super.key,
  });

  final Rate rate;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = rate.isGold ? AppColors.gold : AppColors.teal;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: rate.isGold ? AppColors.goldTint : AppColors.mint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                rate.code,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(rate.name, style: AppTextStyles.rowTitle),
                      ),
                      const SizedBox(width: 3),
                      IconButton(
                        onPressed: onFavorite,
                        tooltip: favorite ? 'Remove favorite' : 'Add favorite',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        icon: Icon(
                          favorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 17,
                          color: favorite
                              ? AppColors.gold
                              : AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    rate.updatedAt == null
                        ? 'Waiting for data'
                        : 'Updated ${timeAgo(rate.updatedAt!, DateTime.now())}',
                    style: rate.isStale
                        ? AppTextStyles.caption.copyWith(color: AppColors.amber)
                        : AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rate.value,
                  style: AppTextStyles.rowTitle.copyWith(fontSize: 14),
                ),
                Text(rate.unit, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                ChangePill(change: rate.change, isUp: rate.isUp),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EnhancedRateChart extends StatefulWidget {
  const EnhancedRateChart({
    required this.rate,
    required this.values,
    required this.range,
    required this.onRangeChanged,
    super.key,
  });

  final Rate rate;
  final List<double> values;
  final String range;
  final ValueChanged<String> onRangeChanged;

  @override
  State<EnhancedRateChart> createState() => _EnhancedRateChartState();
}

class _EnhancedRateChartState extends State<EnhancedRateChart>
    with TickerProviderStateMixin {
  int? _selectedIndex;
  late final AnimationController _drawController;
  late final AnimationController _pulseController;
  late final Animation<double> _drawAnimation;

  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _drawAnimation = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeOutCubic,
    );
    _drawController.addListener(_repaintChart);
    _pulseController.addListener(_repaintChart);
    _drawController.forward();
  }

  void _repaintChart() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant EnhancedRateChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rate.id != widget.rate.id ||
        oldWidget.range != widget.range ||
        oldWidget.values != widget.values) {
      _selectedIndex = null;
      _drawController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _drawController.removeListener(_repaintChart);
    _pulseController.removeListener(_repaintChart);
    _drawController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = downsample(widget.values, 120);
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: values.length < 2
              ? Center(
                  child: Text(
                    'Loading price history…',
                    style: AppTextStyles.caption,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onPanDown: (details) => _selectPoint(
                        details.localPosition,
                        constraints.maxWidth,
                        values.length,
                      ),
                      onPanUpdate: (details) => _selectPoint(
                        details.localPosition,
                        constraints.maxWidth,
                        values.length,
                      ),
                      onTapDown: (details) => _selectPoint(
                        details.localPosition,
                        constraints.maxWidth,
                        values.length,
                      ),
                      onTapCancel: () => setState(() => _selectedIndex = null),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CustomPaint(
                            size: Size(constraints.maxWidth, 220),
                            painter: _EnhancedChartPainter(
                              values: values,
                              rateId: widget.rate.id,
                              selectedIndex: _selectedIndex,
                              drawProgress: _drawAnimation.value,
                              pulseProgress: _pulseController.value,
                            ),
                          ),
                          if (_selectedIndex != null)
                            Positioned(
                              left: _tooltipLeft(
                                constraints.maxWidth,
                                _selectedIndex!,
                                values.length,
                              ),
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Rs ${formatPkr(values[_selectedIndex!], decimals: widget.rate.isGold ? 0 : 2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['1W', '1M', '3M', '1Y'].map((item) {
            final selected = widget.range == item;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                label: Text(item),
                selected: selected,
                showCheckmark: false,
                onSelected: (_) => widget.onRangeChanged(item),
                selectedColor: AppColors.teal,
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: AppColors.divider),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _selectPoint(Offset position, double width, int count) {
    const left = 44.0;
    const right = 8.0;
    final chartWidth = width - left - right;
    final ratio = ((position.dx - left) / chartWidth)
        .clamp(0.0, 1.0)
        .toDouble();
    setState(() => _selectedIndex = (ratio * (count - 1)).round());
  }

  double _tooltipLeft(double width, int index, int count) {
    const left = 44.0;
    const right = 8.0;
    final chartWidth = width - left - right;
    final x = left + chartWidth * index / (count - 1);
    return (x - 42).clamp(0.0, width - 84);
  }
}

class _EnhancedChartPainter extends CustomPainter {
  _EnhancedChartPainter({
    required this.values,
    required this.rateId,
    required this.selectedIndex,
    required this.drawProgress,
    required this.pulseProgress,
  });

  final List<double> values;
  final String rateId;
  final int? selectedIndex;
  final double drawProgress;
  final double pulseProgress;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0;
    const right = 8.0;
    const top = 34.0;
    const bottom = 24.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final lineColor = ChartColors.forRate(rateId);
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = top + chartHeight * i / 3;
      _dashedLine(canvas, Offset(left, y), Offset(size.width - right, y), grid);
      final labelValue = hi - (hi - lo) * i / 3;
      _axisLabel(canvas, _axisLabelValue(labelValue), Offset(0, y - 6), 40);
    }

    const labels = ['Start', 'Mid', 'Now'];
    for (var i = 0; i < labels.length; i++) {
      final x = left + chartWidth * i / 2;
      _axisLabel(canvas, labels[i], Offset(x - 12, size.height - 17), 34);
    }

    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          left + chartWidth * i / (values.length - 1),
          top +
              chartHeight *
                  (1 - (hi == lo ? .5 : (values[i] - lo) / (hi - lo))),
        ),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midpoint = (previous.dx + current.dx) / 2;
      path.cubicTo(
        midpoint,
        previous.dy,
        midpoint,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fill = Path.from(path)
      ..lineTo(size.width - right, size.height - bottom)
      ..lineTo(left, size.height - bottom)
      ..close();
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        left,
        0,
        (chartWidth * drawProgress).clamp(0.0, chartWidth),
        size.height,
      ),
    );
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withAlpha(55), lineColor.withAlpha(0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    final latest = points.last;
    final pulseRadius = 8 + 5 * pulseProgress;
    canvas.drawCircle(
      latest,
      pulseRadius,
      Paint()..color = lineColor.withAlpha(18),
    );
    canvas.drawCircle(latest, 4, Paint()..color = AppColors.surface);
    canvas.drawCircle(
      latest,
      4,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    if (selectedIndex != null) {
      final index = selectedIndex!.clamp(0, points.length - 1);
      final point = points[index];
      canvas.drawLine(
        Offset(point.dx, top),
        Offset(point.dx, size.height - bottom),
        Paint()
          ..color = lineColor.withAlpha(110)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(point, 7, Paint()..color = AppColors.surface);
      canvas.drawCircle(
        point,
        7,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _dashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 5.0;
    const gap = 5.0;
    var x = start.dx;
    while (x < end.dx) {
      canvas.drawLine(
        Offset(x, start.dy),
        Offset(math.min(x + dash, end.dx), end.dy),
        paint,
      );
      x += dash + gap;
    }
  }

  void _axisLabel(Canvas canvas, String text, Offset offset, double width) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.secondary,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  String _axisLabelValue(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
    }
    return value.toStringAsFixed(value < 100 ? 1 : 0);
  }

  @override
  bool shouldRepaint(covariant _EnhancedChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.rateId != rateId ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.drawProgress != drawProgress ||
      oldDelegate.pulseProgress != pulseProgress;
}

class RateChart extends StatelessWidget {
  const RateChart({
    required this.rate,
    required this.values,
    required this.range,
    required this.onRangeChanged,
    super.key,
  });

  final Rate rate;
  final List<double> values;
  final String range;
  final ValueChanged<String> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: values.length < 2
              ? Center(
                  child: Text(
                    'Loading price history…',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                )
              : CustomPaint(
                  painter: _ChartPainter(
                    values: downsample(values, 120),
                    isGold: rate.isGold,
                  ),
                ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          children: ['1W', '1M', '3M', '1Y']
              .map(
                (item) => ChoiceChip(
                  label: Text(item),
                  selected: range == item,
                  showCheckmark: false,
                  onSelected: (_) => onRangeChanged(item),
                  selectedColor: AppColors.teal,
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: AppColors.divider),
                  labelStyle: TextStyle(
                    color: range == item ? Colors.white : AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.values, required this.isGold});

  final List<double> values;
  final bool isGold;

  @override
  void paint(Canvas canvas, Size size) {
    final lineColor = isGold ? AppColors.gold : AppColors.teal;
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (var y = 18.0; y < size.height; y += 38) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          size.width * i / (values.length - 1),
          size.height *
              (.12 +
                  .76 * (1 - (hi == lo ? .5 : (values[i] - lo) / (hi - lo)))),
        ),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final midpoint = (previous.dx + current.dx) / 2;
      path.cubicTo(
        midpoint,
        previous.dy,
        midpoint,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          colors: [lineColor.withAlpha(40), lineColor.withAlpha(0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    final latest = points.last;
    canvas.drawCircle(latest, 9, Paint()..color = lineColor.withAlpha(30));
    canvas.drawCircle(latest, 4, Paint()..color = AppColors.surface);
    canvas.drawCircle(
      latest,
      4,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.isGold != isGold;
}

class PurchaseCalculatorSheet extends StatefulWidget {
  const PurchaseCalculatorSheet({required this.gold, super.key});

  final Rate gold;

  @override
  State<PurchaseCalculatorSheet> createState() =>
      _PurchaseCalculatorSheetState();
}

class _PurchaseCalculatorSheetState extends State<PurchaseCalculatorSheet> {
  int _purity = 24;
  final TextEditingController _grams = TextEditingController(text: '10');
  double _makingCharge = 3;

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grams = double.tryParse(_grams.text) ?? 0;
    final goldPerTola = widget.gold.amount ?? 0;
    final perGram = goldPerTola / gramsPerTola;
    final purityFactor = _purity / 24;
    final metal = perGram * purityFactor * grams;
    final estimated = metal * (1 + _makingCharge / 100);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gold purchase calculator', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 6),
            Text(
              'Estimate metal value and an optional making-charge allowance.',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 18),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 24, label: Text('24K')),
                ButtonSegment(value: 22, label: Text('22K')),
                ButtonSegment(value: 18, label: Text('18K')),
              ],
              selected: {_purity},
              onSelectionChanged: (value) =>
                  setState(() => _purity = value.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.teal
                      : AppColors.surface,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _grams,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Quantity',
                suffixText: 'grams',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Making charge',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Slider(
              value: _makingCharge,
              min: 0,
              max: 20,
              divisions: 20,
              activeColor: AppColors.teal,
              label: '${_makingCharge.toStringAsFixed(0)}%',
              onChanged: (value) => setState(() => _makingCharge = value),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated purchase value',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    goldPerTola == 0
                        ? 'Waiting for live price'
                        : 'Rs ${formatPkr(estimated, decimals: 0)}',
                    style: AppTextStyles.hero.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Metal: Rs ${formatPkr(metal, decimals: 0)} · ${_purity}K · ${grams.toStringAsFixed(grams.truncateToDouble() == grams ? 0 : 1)}g',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Reference estimate only. Confirm purity, making charges and local taxes with the jeweller.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({
    required this.title,
    required this.progress,
    required this.enabled,
    required this.isGold,
    required this.onChanged,
    super.key,
  });

  final String title;
  final double progress;
  final bool enabled;
  final bool isGold;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isGold ? AppColors.goldTint : AppColors.mint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                isGold ? Icons.monetization_on_outlined : Icons.attach_money,
                color: isGold ? AppColors.gold : AppColors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.rowTitle),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: AppColors.mint,
                      valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: AppColors.teal,
              activeTrackColor: AppColors.mint,
            ),
          ],
        ),
      ),
    );
  }
}

class AlertFormSheet extends StatefulWidget {
  const AlertFormSheet({required this.rates, required this.onSave, super.key});

  final List<Rate> rates;
  final ValueChanged<PriceAlert> onSave;

  @override
  State<AlertFormSheet> createState() => _AlertFormSheetState();
}

class _AlertFormSheetState extends State<AlertFormSheet> {
  bool _above = true;
  String _rateId = 'gold';
  final _targetController = TextEditingController();

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('Create alert', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 6),
            Text(
              'Get notified when a rate reaches your target.',
              style: AppTextStyles.subtitle,
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<String>(
              initialValue: _rateId,
              decoration: const InputDecoration(labelText: 'Rate'),
              items: widget.rates
                  .map(
                    (rate) => DropdownMenuItem(
                      value: rate.id,
                      child: Text(rate.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _rateId = value ?? 'gold'),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Goes above')),
                ButtonSegment(value: false, label: Text('Goes below')),
              ],
              selected: {_above},
              onSelectionChanged: (value) =>
                  setState(() => _above = value.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColors.teal
                      : AppColors.surface,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              style: AppTextStyles.hero.copyWith(fontSize: 30),
              decoration: const InputDecoration(
                labelText: 'Target price',
                prefixText: 'Rs ',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                final target = double.tryParse(
                  _targetController.text.replaceAll(',', '').trim(),
                );
                if (target == null || target <= 0) return;
                widget.onSave(
                  PriceAlert(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    rateId: _rateId,
                    above: _above,
                    target: target,
                  ),
                );
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Save alert'),
            ),
          ],
        ),
      ),
    );
  }
}
