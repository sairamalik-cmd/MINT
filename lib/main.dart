import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mint_ui.dart';
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

/// "14:02", the time a figure was weighed.
String clockTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// A rate's figure without its "Rs " prefix, for the struck slab.
String bareFigure(String value) =>
    value.startsWith('Rs ') ? value.substring(3) : value;

String alertSentence(Rate rate, PriceAlert alert) =>
    '${rate.name} ${alert.above ? 'above' : 'below'} Rs ${formatPkr(alert.target, decimals: rate.isGold ? 0 : 2)}';

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

  static const _tabs = [
    (MintGlyph.coin, 'Overview'),
    (MintGlyph.rate, 'Rates'),
    (MintGlyph.history, 'History'),
    (MintGlyph.alert, 'Alerts'),
    (MintGlyph.assay, 'Advisor'),
  ];

  Rate get selectedRate => _rates.firstWhere((rate) => rate.id == _selected);

  Rate _rateFor(String id) =>
      _rates.firstWhere((rate) => rate.id == id, orElse: () => _rates.first);

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

  /// Weigh again. Speaks only when a new figure was actually struck.
  Future<void> _refresh() async {
    final before = _controller.snapshot?.goldFetchedAt;
    await _controller.refreshManual();
    final after = _controller.snapshot?.goldFetchedAt;
    if (!mounted || _controller.error != null || after == null) return;
    if (after != before) {
      showMintToast(
        context,
        'Weighed.',
        'Rates current to ${clockTime(after)}.',
      );
    }
  }

  void _addAlert(PriceAlert alert) {
    setState(() => _alerts = [..._alerts, alert]);
    _saveAlerts();
    showMintToast(
      context,
      'Kept.',
      'Rings once when ${alertSentence(_rateFor(alert.rateId), alert)}.',
    );
  }

  void _openPurchaseCalculator() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PurchaseCalculatorSheet(gold: _rates.first),
    );
  }

  void _openAlertSuggestions() {
    final gold = _rates.first;
    final current = gold.amount;
    if (current == null) {
      showMintToast(context, 'Not yet.', 'Gold has not been weighed yet.');
      return;
    }
    PriceAlert suggestion(bool above) => PriceAlert(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      rateId: 'gold',
      above: above,
      target: current * (above ? 1.015 : .985),
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHead(
              title: 'Suggested alerts',
              subtitle: 'Two marks either side of today’s gold figure.',
            ),
            const SizedBox(height: 14),
            for (final above in [true, false]) ...[
              _SuggestionRow(
                isUp: above,
                title: above ? 'A 1.5% rise' : 'A 1.5% dip',
                detail:
                    '${above ? 'Above' : 'Below'} Rs ${formatPkr(current * (above ? 1.015 : .985), decimals: 0)}',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _addAlert(suggestion(above));
                },
              ),
              const SizedBox(height: 10),
            ],
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
      builder: (_) => AlertFormSheet(rates: _rates, onSave: _addAlert),
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
                for (final (i, page) in [
                  _overview(),
                  _ratesPage(),
                  _historyPage(),
                  _alertsPage(),
                  _advisorPage(),
                ].indexed)
                  TickerMode(enabled: i == _tab, child: page),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: MintTabBar(
        items: _tabs,
        index: _tab,
        onChanged: (index) => setState(() => _tab = index),
      ),
    );
  }

  /// Every screen: its head, the milled reed, any failure, then the body.
  Widget _page({
    required List<Widget> children,
    String? title,
    String? asideTop,
    String? asideBottom,
  }) {
    final gold = _rates.first;
    final weighed = gold.updatedAt;
    final error = _controller.error;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      children: [
        _ScreenHead(
          title: title,
          asideTop:
              asideTop ??
              (weighed == null
                  ? 'Not weighed'
                  : 'Weighed ${clockTime(weighed)}'),
          asideBottom: asideBottom ?? 'Pakistan · PKR',
          refreshing: _controller.isRefreshing,
          onRefresh: _refresh,
          onAlert: title == null ? _openAlertSheet : null,
        ),
        const Mill(),
        if (error != null) ...[
          const SizedBox(height: 14),
          FailCard(
            message: error,
            trusted: gold.amount == null || weighed == null
                ? null
                : 'Last figure trusted: gold ${gold.value} ${gold.unit}, weighed ${clockTime(weighed)}.',
            onRetry: _refresh,
          ),
        ],
        ...children,
      ],
    );
  }

  Widget _overview() {
    final gold = _rates.first;
    final now = DateTime.now();
    final per10g = gold.amount == null
        ? '—'
        : 'Rs ${formatPkr(gold.amount! / gramsPerTola * 10, decimals: 0)}';
    return _page(
      children: [
        const SizedBox(height: 16),
        Text(dateLine(now).toUpperCase(), style: MintText.label()),
        const SizedBox(height: 6),
        // Greeting: DM Serif Display.
        Text(
          '${greeting(now)}.',
          style: MintText.serif(size: 26, height: 1.15),
        ),
        const SizedBox(height: 2),
        Text(
          'The day’s figures, weighed.',
          style: MintText.body(color: MintColors.mute),
        ),
        const SizedBox(height: 14),
        Slab(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GOLD 24K · PER TOLA',
                style: MintText.label(color: MintColors.slabTint),
              ),
              const SizedBox(height: 10),
              _StruckFigure(currency: 'PKR', figure: bareFigure(gold.value)),
              const SizedBox(height: 8),
              MoveText(
                change: gold.change,
                isUp: gold.isUp,
                suffix: gold.change == '—' ? 'not yet compared' : 'today',
                onSlab: true,
                size: 13,
              ),
              const _SlabRule(),
              Row(
                children: [
                  Expanded(
                    child: _SlabStat(
                      label: 'Weighed',
                      value: gold.updatedAt == null
                          ? '—'
                          : '${timeAgo(gold.updatedAt!, now)}${gold.isStale ? ' · stale' : ''}',
                    ),
                  ),
                  _SlabStat(label: 'Per 10 g', value: per10g, end: true),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        EnhancedRateChart(
          rate: gold,
          values: _controller.chartValues(gold.id, _range),
          range: _range,
          onRangeChanged: _setRange,
        ),
        const SizedBox(height: 14),
        _buildInsight(gold),
        SectionRule(
          number: '01',
          name: 'Today’s rates',
          aside: 'the pairs on your counter',
        ),
        _ratesTable(_rates),
        const SizedBox(height: 6),
        Text(
          'Gold edge: the pair you are weighing. Tap a pair to see its history.',
          style: MintText.caption(),
        ),
        const SizedBox(height: 18),
        Text(
          'Gold is the international spot price converted to PKR. '
          'Currency rates by ExchangeRate-API. Reference prices only; '
          'local market rates may differ.',
          style: MintText.caption(),
        ),
      ],
    );
  }

  Widget _ratesPage() {
    return _page(
      title: 'Rates',
      children: [
        const SizedBox(height: 12),
        Text(
          'Live market prices in Pakistani rupees.',
          style: MintText.body(color: MintColors.mute),
        ),
        const SectionRule(number: '01', name: 'Gold', aside: 'per tola'),
        _ratesTable([_rates[0]]),
        const SectionRule(
          number: '02',
          name: 'Currencies',
          aside: 'one unit, in rupees',
        ),
        _ratesTable(_rates.skip(1).toList()),
        const SizedBox(height: 8),
        Text(
          'Starred pairs are the ones you watch. Tap a pair to see its history.',
          style: MintText.caption(),
        ),
      ],
    );
  }

  Widget _historyPage() {
    final rate = selectedRate;
    final past = _pastValues(rate);
    return _page(
      title: 'History',
      children: [
        const SizedBox(height: 12),
        Text(
          'Where each rate has been.',
          style: MintText.body(color: MintColors.mute),
        ),
        const SizedBox(height: 12),
        MintSegmented<String>(
          scrollable: true,
          options: [for (final rate in _rates) (rate.id, rate.code)],
          selected: _selected,
          onChanged: (id) => setState(() => _selected = id),
        ),
        const SizedBox(height: 14),
        EnhancedRateChart(
          rate: rate,
          values: _controller.chartValues(rate.id, _range),
          range: _range,
          onRangeChanged: _setRange,
        ),
        SectionRule(
          number: '01',
          name: 'Past values',
          aside: 'each day’s close',
        ),
        if (past.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Past values appear here as MINT records each day.',
              style: MintText.body(color: MintColors.mute),
            ),
          )
        else
          _MintTable(
            headings: const ['Day', 'Close', 'Move'],
            rows: [
              for (final item in past)
                _MintTableRow(
                  cells: [
                    Text(item.$1, style: MintText.head(size: 15)),
                    Text(item.$2, style: MintText.mono(size: 13.5)),
                    MoveText(change: item.$3, isUp: item.$4),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  Widget _alertsPage() {
    final active = _alerts.where((alert) => !alert.triggered).toList();
    final triggered = _alerts.where((alert) => alert.triggered).toList();
    return _page(
      title: 'Alerts',
      asideTop: '${active.length} set',
      asideBottom: 'ring once',
      children: [
        const SizedBox(height: 14),
        if (active.isEmpty)
          Porcelain(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nothing set to ring.', style: MintText.head(size: 16)),
                const SizedBox(height: 2),
                Text(
                  'Set a figure and it is weighed with every refresh.',
                  style: MintText.caption(),
                ),
              ],
            ),
          )
        else
          for (final alert in active) _alertCard(alert),
        if (triggered.isNotEmpty) ...[
          const SectionRule(
            number: '01',
            name: 'Rung',
            aside: 'it rang once, then rested',
          ),
          const SizedBox(height: 8),
          for (final alert in triggered)
            Opacity(opacity: .55, child: _alertCard(alert)),
        ],
        const SizedBox(height: 6),
        MintButton(label: 'Add an alert', onPressed: _openAlertSheet),
      ],
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
      title: 'Advisor',
      asideTop: 'From live rates',
      asideBottom: 'and your history',
      children: [
        const SizedBox(height: 12),
        Text(
          'The assayer’s read: what the figures say, and why.',
          style: MintText.body(color: MintColors.mute),
        ),
        const SizedBox(height: 4),
        _advisorCard(
          glyph: MintGlyph.rate,
          label: 'Market summary',
          body: values.length < 2
              ? 'MINT is still gathering enough history to read the market.'
              : 'Gold is ${gold.amount != null && gold.amount! >= avg ? 'above' : 'below'} its 30-day average. '
                    'Recent range: Rs ${formatPkr(low, decimals: 0)} to Rs ${formatPkr(high, decimals: 0)} per tola.',
          action: 'View gold history',
          onAction: () => setState(() {
            _selected = 'gold';
            _tab = 2;
          }),
        ),
        _advisorCard(
          glyph: MintGlyph.calc,
          label: 'Purchase calculator',
          body: 'Weigh 24K, 22K and 18K before visiting a jeweller.',
          action: 'Weigh a purchase',
          onAction: _openPurchaseCalculator,
        ),
        _advisorCard(
          glyph: MintGlyph.swap,
          label: 'Currency guidance',
          body:
              '${usd.name}: ${usd.change == '—' ? 'not yet compared' : '${usd.isUp ? '▲' : '▼'} ${usd.change} today'}. '
              'Exchange-rate movement can move the PKR gold price.',
          action: 'Open rates',
          onAction: () => setState(() => _tab = 1),
        ),
        _advisorCard(
          glyph: MintGlyph.alert,
          label: 'Suggested alerts',
          body: gold.amount == null
              ? 'Gold has not been weighed yet.'
              : 'Watch for gold above Rs ${formatPkr(gold.amount! * 1.015, decimals: 0)} or below Rs ${formatPkr(gold.amount! * .985, decimals: 0)}.',
          action: 'Set a suggested alert',
          onAction: _openAlertSuggestions,
        ),
        const SizedBox(height: 18),
        Text(
          'Advisor suggestions use your live and historical market data. '
          'They are not guaranteed outcomes or personal financial advice.',
          style: MintText.caption(),
        ),
      ],
    );
  }

  Widget _advisorCard({
    required MintGlyph glyph,
    required String label,
    required String body,
    required String action,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Porcelain(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Disk(child: MintIcon(glyph, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: MintText.head())),
              ],
            ),
            const SizedBox(height: 10),
            Text(body, style: MintText.body()),
            const SizedBox(height: 2),
            MintLink(label: action, onTap: onAction),
          ],
        ),
      ),
    );
  }

  Widget _alertCard(PriceAlert alert) {
    final rate = _rateFor(alert.rateId);
    final current = rate.amount ?? 0;
    final progress = alert.above
        ? (current / alert.target).clamp(0.0, 1.0)
        : (alert.target == 0
              ? 0.0
              : (1 - current / alert.target).clamp(0.0, 1.0));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AlertCard(
        title: alertSentence(rate, alert),
        isUp: alert.above,
        progress: progress.toDouble(),
        enabled: alert.enabled,
        triggered: alert.triggered,
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

  Widget _buildInsight(Rate gold) {
    final values = _controller.chartValues(gold.id, '1W');
    final change = values.length < 2
        ? null
        : (values.last - values.first) / values.first * 100;
    final title = change == null
        ? 'Still weighing the market.'
        : change < -1
        ? 'Consider a small, staged buy.'
        : change > 1
        ? 'Consider waiting for a pullback.'
        : 'Hold, and compare before buying.';
    final detail = change == null
        ? 'MINT needs more live history before it can suggest anything useful.'
        : 'Gold moved ${change < 0 ? '▼' : '▲'} ${change.abs().toStringAsFixed(2)}% over the week. '
              'A trend signal, not financial advice.';
    return Porcelain(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Disk(child: MintIcon(MintGlyph.assay, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THE ASSAYER’S READ', style: MintText.label()),
                const SizedBox(height: 4),
                Text(title, style: MintText.head()),
                const SizedBox(height: 4),
                Text(detail, style: MintText.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratesTable(List<Rate> rates) {
    final now = DateTime.now();
    return _MintTable(
      headings: const ['Pair', 'Rate', '24 h'],
      rows: [
        for (final rate in rates)
          _MintTableRow(
            highlighted: rate.id == _selected,
            onTap: () => setState(() {
              _selected = rate.id;
              _tab = 2;
            }),
            cells: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Legend dot: the same color as this pair's chart line.
                      CurrencyDot(id: rate.id),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          rate.name,
                          style: MintText.head(size: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _Star(
                        on: _favorites.contains(rate.id),
                        onTap: () => setState(
                          () => _favorites.contains(rate.id)
                              ? _favorites.remove(rate.id)
                              : _favorites.add(rate.id),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      rate.updatedAt == null
                          ? 'not weighed yet'
                          : '${rate.unit.replaceFirst('/ ', 'per ')} · ${timeAgo(rate.updatedAt!, now)}${rate.isStale ? ' · stale' : ''}',
                      style: MintText.caption(
                        color: rate.isStale ? MintColors.hoji : MintColors.mute,
                      ),
                    ),
                  ),
                ],
              ),
              Text(rate.value, style: MintText.mono(size: 13.5)),
              MoveText(change: rate.change, isUp: rate.isUp),
            ],
          ),
      ],
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

/// A small dot in a currency's own chart color, used as a legend marker.
class CurrencyDot extends StatelessWidget {
  const CurrencyDot({required this.id, this.size = 8, super.key});

  /// A rate id ('gold', 'usd', 'sar', ...) or a currency code.
  final String id;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: MintColors.currencyGraph(id),
      shape: BoxShape.circle,
    ),
  );
}

/// The head of every screen: the wordmark (or the screen's title), when it
/// was weighed, and the way to weigh again.
class _ScreenHead extends StatelessWidget {
  const _ScreenHead({
    required this.title,
    required this.asideTop,
    required this.asideBottom,
    required this.refreshing,
    required this.onRefresh,
    this.onAlert,
  });

  final String? title;
  final String asideTop;
  final String asideBottom;
  final bool refreshing;
  final VoidCallback onRefresh;
  final VoidCallback? onAlert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: title == null
                ? const MintWordmark()
                : Text(title!, style: MintText.display()),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${asideTop.toUpperCase()}\n'),
                  TextSpan(
                    text: asideBottom.toUpperCase(),
                    style: const TextStyle(color: MintColors.mute),
                  ),
                ],
              ),
              textAlign: TextAlign.right,
              style: MintText.label(color: MintColors.ink)
                  .copyWith(height: 1.4),
            ),
          ),
          const SizedBox(width: 10),
          if (onAlert != null) ...[
            RoundButton(
              tooltip: 'Set an alert',
              onPressed: onAlert,
              child: const MintIcon(MintGlyph.alert),
            ),
            const SizedBox(width: 8),
          ],
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: RoundButton(
              tooltip: 'Weigh again',
              onPressed: refreshing ? null : onRefresh,
              child: refreshing
                  ? const Whisk(size: 22)
                  : const MintIcon(MintGlyph.rate),
            ),
          ),
        ],
      ),
    );
  }
}

/// MINT wordmark with the matching MINT coin mark.
class MintWordmark extends StatelessWidget {
  const MintWordmark({this.size = 54, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/mint_logo.png', width: 34, height: 34),
          const SizedBox(width: 6),
          Text(
            'MINT',
            style: MintText.logo(size: 17, color: MintColors.deep),
            semanticsLabel: 'MINT',
          ),
        ],
      ),
    );
  }
}

/// A figure struck on the slab: small currency label, big DM Serif number.
class _StruckFigure extends StatelessWidget {
  const _StruckFigure({required this.currency, required this.figure});

  final String currency;
  final String figure;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 9, right: 6),
            child: Text(
              currency,
              style: MintText.mono(
                size: 12,
                weight: FontWeight.w600,
                color: MintColors.slabTint,
                letterSpacing: 1,
              ),
            ),
          ),
          Text(figure, style: MintText.figure()),
        ],
      ),
    );
  }
}

class _SlabRule extends StatelessWidget {
  const _SlabRule();

  @override
  Widget build(BuildContext context) => Container(
    height: .75,
    margin: const EdgeInsets.only(top: 12, bottom: 10),
    color: MintColors.slabTint.withAlpha(102),
  );
}

class _SlabStat extends StatelessWidget {
  const _SlabStat({required this.label, required this.value, this.end = false});

  final String label;
  final String value;
  final bool end;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: MintText.label(color: MintColors.slabTint),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: MintText.mono(
          size: 14,
          weight: FontWeight.w500,
          color: MintColors.stock,
        ),
      ),
    ],
  );
}

/// A small sunken disk holding an icon.
class _Disk extends StatelessWidget {
  const _Disk({required this.child});

  static const size = 42.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Well(
      radius: size / 2,
      padding: EdgeInsets.zero,
      child: Center(child: child),
    ),
  );
}

class _Star extends StatelessWidget {
  const _Star({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: on ? 'Stop watching' : 'Watch',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(
          on ? Icons.star_rounded : Icons.star_border_rounded,
          size: 17,
          color: on ? MintColors.gold : MintColors.glazeDeep,
        ),
      ),
    ),
  );
}

/// A ledger table: small uppercase heads over an ink rule, glaze hairlines
/// between rows. The highlighted row carries a powder band and a gold edge.
class _MintTable extends StatelessWidget {
  const _MintTable({required this.headings, required this.rows});

  final List<String> headings;
  final List<_MintTableRow> rows;

  static const flex = [5, 3, 2];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: MintColors.ink, width: 1.5),
            ),
          ),
          child: Row(
            children: [
              for (var i = 0; i < headings.length; i++)
                Expanded(
                  flex: flex[i],
                  child: Text(
                    headings[i].toUpperCase(),
                    textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                    style: MintText.label(size: 10),
                  ),
                ),
            ],
          ),
        ),
        ...rows,
      ],
    );
  }
}

class _MintTableRow extends StatelessWidget {
  const _MintTableRow({
    required this.cells,
    this.highlighted = false,
    this.onTap,
  });

  final List<Widget> cells;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: highlighted ? MintColors.hiRow : null,
        border: const Border(
          bottom: BorderSide(color: MintColors.glaze, width: .75),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: _MintTable.flex[i],
              child: Align(
                alignment: i == 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: cells[i],
              ),
            ),
        ],
      ),
    );
    final body = highlighted
        ? Stack(
            children: [
              row,
              Positioned(
                left: 0,
                top: 0,
                bottom: .75,
                child: Container(width: 4, color: MintColors.gold),
              ),
            ],
          )
        : row;
    return onTap == null
        ? body
        : Semantics(
            button: true,
            selected: highlighted,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: body,
            ),
          );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.isUp,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final bool isUp;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Porcelain(
      child: Row(
        children: [
          _Disk(
            child: Text(
              isUp ? '▲' : '▼',
              style: MintText.mono(size: 14, color: MintColors.move(isUp)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MintText.head()),
                Text(
                  detail,
                  style: MintText.mono(size: 12.5, color: MintColors.mute),
                ),
              ],
            ),
          ),
          const MintIcon(MintGlyph.plus, size: 20),
        ],
      ),
    ),
  );
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

  static const ranges = ['1W', '1M', '3M', '1Y'];
  static const rangeWords = {
    '1W': 'this week',
    '1M': 'this month',
    '3M': 'in three months',
    '1Y': 'this year',
  };

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
        !listEquals(oldWidget.values, widget.values)) {
      _selectedIndex = null;
      _drawController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _drawController.removeListener(_repaintChart);
    _drawController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _money(double value) =>
      'Rs ${formatPkr(value, decimals: widget.rate.isGold ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    final values = downsample(widget.values, 120);
    final hasData = values.length >= 2;
    final change = hasData ? (values.last / values.first - 1) * 100 : null;
    // Each currency draws in its own color.
    final color = MintColors.currencyGraph(widget.rate.id);
    return Porcelain(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    CurrencyDot(id: widget.rate.id),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${widget.rate.name.toUpperCase()} · ${widget.range}',
                        style: MintText.label(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              MintSegmented<String>(
                mini: true,
                options: [for (final r in EnhancedRateChart.ranges) (r, r)],
                selected: widget.range,
                onChanged: widget.onRangeChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (change != null)
            Row(
              children: [
                Text(
                  '${_money(values.last)}  ',
                  style: MintText.mono(size: 12, weight: FontWeight.w600),
                ),
                MoveText(
                  change: '${change.abs().toStringAsFixed(2)}%',
                  isUp: change >= 0,
                  suffix: EnhancedRateChart.rangeWords[widget.range],
                ),
              ],
            ),
          SizedBox(
            height: 180,
            child: !hasData
                ? Center(
                    child: Text(
                      'Gathering price history…',
                      style: MintText.caption(),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      void select(Offset p) =>
                          _selectPoint(p, width, values.length);
                      return GestureDetector(
                        onPanDown: (d) => select(d.localPosition),
                        onPanUpdate: (d) => select(d.localPosition),
                        onTapDown: (d) => select(d.localPosition),
                        onTapCancel: () =>
                            setState(() => _selectedIndex = null),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            RepaintBoundary(
                              child: CustomPaint(
                                size: Size(width, 180),
                                painter: _EnhancedChartPainter(
                                  values: values,
                                  color: color,
                                  selectedIndex: _selectedIndex,
                                  drawProgress: _drawAnimation.value,
                                ),
                              ),
                            ),
                            if (_drawAnimation.value > .98)
                              CustomPaint(
                                size: Size(width, 180),
                                painter: _PulsePainter(
                                  values: values,
                                  color: color,
                                  pulse: _pulseController,
                                ),
                              ),
                            if (_selectedIndex != null)
                              Positioned(
                                left: _tooltipLeft(
                                  width,
                                  _selectedIndex!,
                                  values.length,
                                ),
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MintColors.ink,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _money(values[_selectedIndex!]),
                                    style: MintText.mono(
                                      size: 10.5,
                                      weight: FontWeight.w600,
                                      color: MintColors.stock,
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
          if (hasData)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: MintColors.glaze, width: .75),
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: _stat('Open', _money(values.first))),
                  Expanded(
                    child: _stat('High', _money(values.reduce(math.max))),
                  ),
                  Expanded(
                    child: _stat(
                      'Low',
                      _money(values.reduce(math.min)),
                      end: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {bool end = false}) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(), style: MintText.label()),
      const SizedBox(height: 1),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, style: MintText.mono(weight: FontWeight.w500)),
      ),
    ],
  );

  void _selectPoint(Offset position, double width, int count) {
    final chartWidth =
        width - _EnhancedChartPainter.left - _EnhancedChartPainter.right;
    final ratio = ((position.dx - _EnhancedChartPainter.left) / chartWidth)
        .clamp(0.0, 1.0)
        .toDouble();
    setState(() => _selectedIndex = (ratio * (count - 1)).round());
  }

  double _tooltipLeft(double width, int index, int count) {
    final chartWidth =
        width - _EnhancedChartPainter.left - _EnhancedChartPainter.right;
    final x = _EnhancedChartPainter.left + chartWidth * index / (count - 1);
    return (x - 42).clamp(0.0, width - 96);
  }
}

/// The latest figure, ringed in the currency's color and breathing.
/// Repaints on its own.
class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.values,
    required this.color,
    required this.pulse,
  }) : super(repaint: pulse);

  final List<double> values;
  final Color color;
  final Animation<double> pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final latest = _EnhancedChartPainter.pointAt(
      values,
      values.length - 1,
      size,
    );
    final t = pulse.value;
    canvas.drawCircle(
      latest,
      7 + 5 * t,
      Paint()..color = color.withValues(alpha: .28 * (1 - t)),
    );
    canvas.drawCircle(latest, 5.5, Paint()..color = MintColors.stock);
    canvas.drawCircle(
      latest,
      5.5,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter old) =>
      old.values != values || old.color != color;
}

/// The chart: a line in the currency's color over powder that lies thinner
/// toward the base, the latest figure ringed, values on the right.
class _EnhancedChartPainter extends CustomPainter {
  _EnhancedChartPainter({
    required this.values,
    required this.color,
    required this.selectedIndex,
    required this.drawProgress,
  });

  static const left = 2.0;
  static const right = 46.0;
  static const top = 24.0;
  static const bottom = 20.0;

  final List<double> values;
  final Color color;
  final int? selectedIndex;
  final double drawProgress;

  /// Where value [i] sits on the chart: one formula for the line and the pulse.
  static Offset pointAt(List<double> values, int i, Size size) {
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    final pad = (hi - lo) * .12;
    lo -= pad;
    hi += pad;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    return Offset(
      left + chartWidth * i / (values.length - 1),
      top + chartHeight * (1 - (hi == lo ? .5 : (values[i] - lo) / (hi - lo))),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final base = size.height - bottom;
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    final pad = (hi - lo) * .12;
    lo -= pad;
    hi += pad;
    double yOf(double v) =>
        top + chartHeight * (1 - (hi == lo ? .5 : (v - lo) / (hi - lo)));

    final grid = Paint()
      ..color = MintColors.glazeDeep
      ..strokeWidth = .75;
    for (var i = 0; i < 4; i++) {
      final y = top + chartHeight * i / 3;
      _dashedLine(
        canvas,
        Offset(left, y),
        Offset(size.width - right + 6, y),
        grid,
      );
      _label(
        canvas,
        _axisValue(hi - (hi - lo) * i / 3),
        Offset(size.width - right + 10, y - 7),
      );
    }
    const xs = ['Start', 'Mid', 'Now'];
    for (var i = 0; i < xs.length; i++) {
      final x = left + chartWidth * i / 2;
      _label(
        canvas,
        xs[i],
        Offset(i == 0 ? x : x - (i == 1 ? 12 : 22), size.height - 14),
      );
    }

    final points = [
      for (var i = 0; i < values.length; i++) pointAt(values, i, size),
    ];
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final mid = (previous.dx + current.dx) / 2;
      path.cubicTo(mid, previous.dy, mid, current.dy, current.dx, current.dy);
    }

    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        left,
        0,
        (chartWidth * drawProgress).clamp(0.0, chartWidth) + 1,
        size.height,
      ),
    );
    // The area is powder density: thick under the line, sparse at the base.
    // Both grain tones are shades of the currency's own color.
    final darkGrain = Color.lerp(color, Colors.black, .18)!;
    final lightGrain = Color.lerp(color, Colors.white, .4)!;
    final random = math.Random(77);
    final dot = Paint();
    for (var i = 0; i < 1100; i++) {
      final x = left + random.nextDouble() * chartWidth;
      final fi = (x - left) / (chartWidth / (values.length - 1));
      final i0 = math.min(values.length - 2, fi.floor());
      final f = fi - i0;
      final eased = f * f * (3 - 2 * f);
      final yLine = yOf(values[i0] + (values[i0 + 1] - values[i0]) * eased);
      final depth = math.pow(random.nextDouble(), 1.9).toDouble();
      final y = yLine + 1.5 + depth * (base - yLine);
      dot.color = (random.nextDouble() < .55 ? darkGrain : lightGrain)
          .withValues(alpha: (.9 - depth * .6).clamp(0, 1));
      canvas.drawCircle(Offset(x, y), .45 + random.nextDouble() * .85, dot);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    canvas.drawLine(
      Offset(left, base),
      Offset(size.width - right + 6, base),
      Paint()
        ..color = MintColors.ink
        ..strokeWidth = 1.2,
    );

    if (selectedIndex != null) {
      final point = points[selectedIndex!.clamp(0, points.length - 1)];
      canvas.drawLine(
        Offset(point.dx, top),
        Offset(point.dx, base),
        Paint()
          ..color = MintColors.ink.withValues(alpha: .45)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(point, 6, Paint()..color = MintColors.stock);
      canvas.drawCircle(
        point,
        6,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _dashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    var x = start.dx;
    while (x < end.dx) {
      canvas.drawLine(
        Offset(x, start.dy),
        Offset(math.min(x + 2, end.dx), end.dy),
        paint,
      );
      x += 5;
    }
  }

  /// Chart labels: DM Sans.
  void _label(Canvas canvas, String text, Offset offset) {
    TextPainter(
        text: TextSpan(
          text: text,
          style: MintText.mono(size: 10, color: MintColors.mute),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout(maxWidth: 44)
      ..paint(canvas, offset);
  }

  String _axisValue(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k';
    }
    return value.toStringAsFixed(value < 100 ? 1 : 0);
  }

  @override
  bool shouldRepaint(covariant _EnhancedChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.color != color ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.drawProgress != drawProgress;
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
    final raw = _grams.text.trim();
    final parsed = double.tryParse(raw);
    final invalid = raw.isNotEmpty && (parsed == null || parsed < 0);
    final grams = invalid ? 0.0 : (parsed ?? 0);
    final goldPerTola = widget.gold.amount ?? 0;
    final perGram = goldPerTola / gramsPerTola;
    final metal = perGram * (_purity / 24) * grams;
    final estimated = metal * (1 + _makingCharge / 100);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHead(
              title: 'Weigh a purchase',
              subtitle: 'The metal’s worth at today’s fixing, with a making-charge allowance.',
            ),
            const SizedBox(height: 16),
            Text('PURITY', style: MintText.label()),
            const SizedBox(height: 6),
            MintSegmented<int>(
              options: const [(24, '24K'), (22, '22K'), (18, '18K')],
              selected: _purity,
              onChanged: (value) => setState(() => _purity = value),
            ),
            const SizedBox(height: 18),
            Text('WEIGHT', style: MintText.label()),
            const SizedBox(height: 6),
            TextField(
              controller: _grams,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: MintText.mono(size: 20),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                suffixText: 'grams',
                errorText: invalid
                    ? 'Enter a weight in grams, like 12.5.'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('MAKING CHARGE', style: MintText.label()),
                const Spacer(),
                Text(
                  '${_makingCharge.toStringAsFixed(0)}%',
                  style: MintText.mono(size: 12, weight: FontWeight.w600),
                ),
              ],
            ),
            Slider(
              value: _makingCharge,
              min: 0,
              max: 20,
              divisions: 20,
              label: '${_makingCharge.toStringAsFixed(0)}%',
              onChanged: (value) => setState(() => _makingCharge = value),
            ),
            const SizedBox(height: 4),
            Slab(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WORTH AT TODAY’S FIXING',
                    style: MintText.label(color: MintColors.slabTint),
                  ),
                  const SizedBox(height: 10),
                  goldPerTola == 0
                      ? Text(
                          'Gold not weighed yet.',
                          style: MintText.head(
                            size: 18,
                            color: MintColors.stock,
                          ),
                        )
                      : _StruckFigure(
                          currency: 'PKR',
                          figure: formatPkr(estimated, decimals: 0),
                        ),
                  const _SlabRule(),
                  Row(
                    children: [
                      Expanded(
                        child: _SlabStat(
                          label: 'Metal',
                          value: 'Rs ${formatPkr(metal, decimals: 0)}',
                        ),
                      ),
                      _SlabStat(
                        label: '${_purity}K · weight',
                        value:
                            '${grams.toStringAsFixed(grams.truncateToDouble() == grams ? 0 : 1)} g',
                        end: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A reference estimate only. Confirm purity, making charges and local taxes with the jeweller.',
              style: MintText.caption(),
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
    required this.isUp,
    required this.progress,
    required this.enabled,
    required this.triggered,
    required this.isGold,
    required this.onChanged,
    super.key,
  });

  final String title;
  final bool isUp;
  final double progress;
  final bool enabled;
  final bool triggered;
  final bool isGold;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Porcelain(
      child: Row(
        children: [
          _Disk(
            child: MintIcon(isGold ? MintGlyph.coin : MintGlyph.swap, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MintText.head(size: 15)),
                const SizedBox(height: 8),
                _PowderTrack(progress: progress),
                const SizedBox(height: 4),
                Text(
                  triggered
                      ? 'Rang once. Resting.'
                      : '${isUp ? '▲' : '▼'} ${(progress * 100).toStringAsFixed(0)}% of the way',
                  style: MintText.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(value: enabled, onChanged: triggered ? null : onChanged),
        ],
      ),
    );
  }
}

/// A progress track: a sunken well filled with powder.
class _PowderTrack extends StatelessWidget {
  const _PowderTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 9,
    child: Well(
      radius: 5,
      padding: EdgeInsets.zero,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          heightFactor: 1,
          child: const Powder(radius: 5, child: SizedBox.expand()),
        ),
      ),
    ),
  );
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
  bool _showError = false;
  final _targetController = TextEditingController();

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  double? get _target {
    final value = double.tryParse(
      _targetController.text.replaceAll(',', '').trim(),
    );
    return value == null || value <= 0 ? null : value;
  }

  void _save() {
    final target = _target;
    if (target == null) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context);
    widget.onSave(
      PriceAlert(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        rateId: _rateId,
        above: _above,
        target: target,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHead(
              title: 'Set an alert',
              subtitle: 'It rings once when the rate reaches your figure.',
            ),
            const SizedBox(height: 18),
            Text('RATE', style: MintText.label()),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _rateId,
              style: MintText.mono(size: 15, weight: FontWeight.w500),
              dropdownColor: MintColors.stock,
              borderRadius: BorderRadius.circular(12),
              items: widget.rates
                  .map(
                    (rate) => DropdownMenuItem(
                      value: rate.id,
                      child: Row(
                        children: [
                          CurrencyDot(id: rate.id),
                          const SizedBox(width: 10),
                          Text(rate.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _rateId = value ?? 'gold'),
            ),
            const SizedBox(height: 16),
            MintSegmented<bool>(
              options: const [(true, '▲ Goes above'), (false, '▼ Goes below')],
              selected: _above,
              onChanged: (value) => setState(() => _above = value),
            ),
            const SizedBox(height: 18),
            Text('TARGET PRICE', style: MintText.label()),
            const SizedBox(height: 6),
            TextField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: MintText.mono(size: 20),
              onChanged: (_) {
                if (_showError) setState(() => _showError = false);
              },
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                prefixText: 'Rs ',
                errorText: _showError
                    ? 'Enter a figure above zero, like 285000.'
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            MintButton(label: 'Keep this alert', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
