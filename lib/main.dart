import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'rates.dart';
import 'theme.dart';

void main() => runApp(const MintApp());

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

  Rate get selectedRate => _rates.firstWhere((rate) => rate.id == _selected);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onRatesChanged);
    _controller.start();
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
  }

  Future<void> _refresh() => _controller.refreshManual();

  void _openAlertSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const AlertFormSheet(),
    );
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
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        children: [
          _DateGreeting(),
          const SizedBox(height: 22),
          LiveIndicator(updatedAt: gold.updatedAt, isStale: gold.isStale),
          const SizedBox(height: 30),
          Text('Gold 24K · per tola (11.6638g)', style: AppTextStyles.subtitle),
          const SizedBox(height: 5),
          Text(gold.value, style: AppTextStyles.hero),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: ChangePill(
              change: gold.change,
              isUp: gold.isUp,
              label: 'today',
            ),
          ),
          const SizedBox(height: 24),
          RateChart(
            rate: gold,
            values: _controller.chartValues(gold.id, _range),
            range: _range,
            onRangeChanged: _setRange,
          ),
          const SizedBox(height: 32),
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
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        children: [
          Text('Rates', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 5),
          Text(
            'Live market prices in Pakistani Rupees',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 30),
          const SectionHeader(title: 'Gold', label: 'PKR'),
          _rateRow(_rates[0]),
          const SizedBox(height: 26),
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
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        children: [
          Text('History', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 5),
          Text(
            'A clearer view of where rates have been.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 26),
          _selector(),
          const SizedBox(height: 20),
          RateChart(
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
    return _page(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        children: [
          Text('Alerts', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 5),
          Text(
            'Know when a rate reaches your target.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 28),
          AlertCard(
            title: '24K Gold goes above Rs 25,000',
            progress: .72,
            enabled: true,
            isGold: true,
          ),
          const SizedBox(height: 12),
          AlertCard(
            title: 'US Dollar goes below Rs 275.00',
            progress: .35,
            enabled: true,
            isGold: false,
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Triggered', label: 'Past alerts'),
          const SizedBox(height: 12),
          Opacity(
            opacity: .48,
            child: AlertCard(
              title: 'Gold reached Rs 24,500',
              progress: 1,
              enabled: false,
              isGold: true,
            ),
          ),
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
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: const Text(
              'M',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
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
          const SizedBox(width: 4),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.mint,
            child: Text(
              'SA',
              style: TextStyle(
                color: AppColors.teal,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
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
          '${greeting(now)}, Saira.',
          style: GoogleFonts.inter(
            fontSize: 24,
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
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
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
                  fontSize: 13,
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
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: Icon(
                          favorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 19,
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
                Text(rate.value, style: AppTextStyles.rowTitle),
                Text(rate.unit, style: AppTextStyles.caption),
                const SizedBox(height: 4),
                ChangePill(change: rate.change, isUp: rate.isUp),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
                    'Collecting data. The chart fills in as rates update.',
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

class AlertCard extends StatelessWidget {
  const AlertCard({
    required this.title,
    required this.progress,
    required this.enabled,
    required this.isGold,
    super.key,
  });

  final String title;
  final double progress;
  final bool enabled;
  final bool isGold;

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
              onChanged: (_) {},
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
  const AlertFormSheet({super.key});

  @override
  State<AlertFormSheet> createState() => _AlertFormSheetState();
}

class _AlertFormSheetState extends State<AlertFormSheet> {
  bool _above = true;

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
              initialValue: 'Gold 24K',
              decoration: const InputDecoration(labelText: 'Rate'),
              items: const [
                DropdownMenuItem(value: 'Gold 24K', child: Text('Gold 24K')),
                DropdownMenuItem(value: 'US Dollar', child: Text('US Dollar')),
                DropdownMenuItem(
                  value: 'Saudi Riyal',
                  child: Text('Saudi Riyal'),
                ),
              ],
              onChanged: (_) {},
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
              keyboardType: TextInputType.number,
              style: AppTextStyles.hero.copyWith(fontSize: 30),
              decoration: const InputDecoration(
                labelText: 'Target price',
                prefixText: 'Rs ',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
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
