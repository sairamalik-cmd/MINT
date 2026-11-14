import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Configuration: every URL and timing lives here.
// ---------------------------------------------------------------------------

const double gramsPerTroyOz = 31.1035;
const double gramsPerTola = 11.6638;

/// The Saudi riyal is pegged to the US dollar, so SAR/PKR = USD/PKR / 3.75.
const double sarPerUsd = 3.75;
const supportedCurrencyCodes = [
  'USD',
  'SAR',
  'AED',
  'EUR',
  'GBP',
  'KRW',
  'JPY',
  'CAD',
  'AUD',
];

class RateConfig {
  const RateConfig._();

  static const goldUrl = 'https://xaus.com/api/v1/spot?compact=1';
  static const fxUrl = 'https://open.er-api.com/v6/latest/USD';
  static const fxFallbackUrl =
      'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.json';

  static const goldRefresh = Duration(seconds: 60);
  static const fxRefresh = Duration(hours: 6);
  static const goldStaleAfter = Duration(hours: 1);
  static const fxStaleAfter = Duration(hours: 30);
  static const historyInterval = Duration(minutes: 15);
  static const manualCooldown = Duration(seconds: 10);
  static const requestTimeout = Duration(seconds: 10);

  /// Percent added to the international gold price to approximate the local
  /// market (0 = pure international reference price).
  static const goldPremiumPercent = 0.0;
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// What the UI shows for one rate. Strings are ready to display.
class Rate {
  const Rate({
    required this.id,
    required this.code,
    required this.name,
    required this.value,
    required this.unit,
    required this.change,
    required this.isUp,
    required this.isGold,
    this.amount,
    this.updatedAt,
    this.isStale = false,
  });

  final String id;
  final String code;
  final String name;
  final String value;
  final String unit;
  final String change;
  final bool isUp;
  final bool isGold;
  final double? amount;
  final DateTime? updatedAt;
  final bool isStale;
}

/// Shown until the first real data arrives (no fake numbers).
const placeholderRates = [
  Rate(
    id: 'gold',
    code: 'Au',
    name: 'Gold 24K',
    value: 'Rs —',
    unit: '/ tola',
    change: '—',
    isUp: true,
    isGold: true,
  ),
  Rate(
    id: 'usd',
    code: '\$',
    name: 'US Dollar',
    value: 'Rs —',
    unit: '/ 1 USD',
    change: '—',
    isUp: true,
    isGold: false,
  ),
  Rate(
    id: 'sar',
    code: 'SR',
    name: 'Saudi Riyal',
    value: 'Rs —',
    unit: '/ 1 SAR',
    change: '—',
    isUp: true,
    isGold: false,
  ),
  Rate(
    id: 'aed',
    code: 'AED',
    name: 'UAE Dirham',
    value: 'Rs —',
    unit: '/ 1 AED',
    change: '—',
    isUp: true,
    isGold: false,
  ),
  Rate(
    id: 'eur',
    code: '€',
    name: 'Euro',
    value: 'Rs —',
    unit: '/ 1 EUR',
    change: '—',
    isUp: true,
    isGold: false,
  ),
  Rate(
    id: 'gbp',
    code: '£',
    name: 'British Pound',
    value: 'Rs —',
    unit: '/ 1 GBP',
    change: '—',
    isUp: true,
    isGold: false,
  ),
  Rate(
    id: 'krw',
    code: '₩',
    name: 'South Korean Won',
    value: 'Rs —',
    unit: '/ 1,000 KRW',
    change: '—',
    isUp: true,
    isGold: false,
  ),
  Rate(
    id: 'jpy',
    code: '¥',
    name: 'Japanese Yen',
    value: 'Rs —',
    unit: '/ 1 JPY',
    change: '—',
    isUp: true,
    isGold: false,
  ),
  Rate(
    id: 'cad',
    code: 'C\$',
    name: 'Canadian Dollar',
    value: 'Rs —',
    unit: '/ 1 CAD',
    change: '—',
    isUp: true,
    isGold: false,
  ),
  Rate(
    id: 'aud',
    code: 'A\$',
    name: 'Australian Dollar',
    value: 'Rs —',
    unit: '/ 1 AUD',
    change: '—',
    isUp: true,
    isGold: false,
  ),
];

class RatePoint {
  const RatePoint(this.time, this.value);

  final DateTime time;
  final double value;

  List<num> toJson() => [time.millisecondsSinceEpoch, value];

  factory RatePoint.fromJson(List<dynamic> json) => RatePoint(
    DateTime.fromMillisecondsSinceEpoch((json[0] as num).toInt()),
    (json[1] as num).toDouble(),
  );
}

class DayClose {
  const DayClose(this.date, this.value);

  final DateTime date;
  final double value;
}

/// The two raw inputs everything else is calculated from.
class MarketSnapshot {
  const MarketSnapshot({
    required this.goldUsdPerOz,
    required this.usdPkr,
    required this.usdRates,
    required this.goldFetchedAt,
    required this.fxFetchedAt,
  });

  final double goldUsdPerOz;
  final double usdPkr;
  final Map<String, double> usdRates;
  final DateTime goldFetchedAt;
  final DateTime fxFetchedAt;

  double get gold24kPkrPerGram =>
      goldUsdPerOz /
      gramsPerTroyOz *
      usdPkr *
      (1 + RateConfig.goldPremiumPercent / 100);

  double get gold24kPkrPer10g => gold24kPkrPerGram * 10;
  double get gold24kPkrPerTola => gold24kPkrPerGram * gramsPerTola;
  double get gold22kPkrPer10g => gold24kPkrPer10g * 22 / 24;
  double pkrPerCurrency(String code) {
    final usdPerUnit = usdRates[code];
    if (usdPerUnit == null || usdPerUnit <= 0) return 0;
    return usdPkr / usdPerUnit;
  }

  double get sarPkr => pkrPerCurrency('SAR');

  Map<String, dynamic> toJson() => {
    'gold': goldUsdPerOz,
    'fx': usdPkr,
    'usdRates': usdRates,
    'goldAt': goldFetchedAt.millisecondsSinceEpoch,
    'fxAt': fxFetchedAt.millisecondsSinceEpoch,
  };

  factory MarketSnapshot.fromJson(Map<String, dynamic> json) => MarketSnapshot(
    goldUsdPerOz: (json['gold'] as num).toDouble(),
    usdPkr: (json['fx'] as num).toDouble(),
    usdRates: {
      for (final entry in (json['usdRates'] as Map? ?? const {}).entries)
        entry.key.toString(): (entry.value as num).toDouble(),
      'SAR': sarPerUsd,
    },
    goldFetchedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['goldAt'] as num).toInt(),
    ),
    fxFetchedAt: DateTime.fromMillisecondsSinceEpoch(
      (json['fxAt'] as num).toInt(),
    ),
  );
}

class RateException implements Exception {
  const RateException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// Network
// ---------------------------------------------------------------------------

class RateService {
  RateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void close() => _client.close();

  /// Gold spot price in USD per troy ounce.
  Future<double> fetchGoldUsdPerOz({double? previous}) async {
    var value = await _getGold();
    if (previous != null &&
        previous > 0 &&
        (value - previous).abs() / previous > 0.10) {
      // A jump of more than 10%: fetch again and only accept it if confirmed.
      final confirm = await _getGold();
      if ((confirm - value).abs() / value > 0.01) {
        throw const RateException('Unusual gold price change ignored');
      }
      value = confirm;
    }
    return value;
  }

  Future<double> _getGold() async {
    final response = await _client
        .get(Uri.parse(RateConfig.goldUrl))
        .timeout(RateConfig.requestTimeout);
    if (response.statusCode != 200) {
      throw RateException('Gold feed returned ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const RateException('Unexpected gold response');
    }
    final value = _parseGoldUsdPerOz(json);
    if (!_isValid(value)) {
      throw const RateException('Gold price missing in response');
    }
    return value!;
  }

  /// Reads the gold price defensively, because field names may change.
  double? _parseGoldUsdPerOz(Map<String, dynamic> json) {
    final direct = _asDouble(json['spot_usd_oz']);
    if (direct != null) return direct;
    final perGram = _asDouble(json['per_gram_usd']);
    if (perGram != null) return perGram * gramsPerTroyOz;
    final xau = json['xau'];
    if (xau is Map) {
      final price = _asDouble(xau['price']);
      final currency = xau['currency']?.toString().toUpperCase();
      final unit = xau['unit']?.toString().toLowerCase() ?? '';
      if (price != null && currency == 'USD') {
        return unit.contains('gram') ? price * gramsPerTroyOz : price;
      }
    }
    return null;
  }

  /// USD to PKR. Tries the primary feed, then the fallback.
  Future<Map<String, double>> fetchUsdRates() async {
    try {
      return await _getFxPrimary();
    } catch (_) {
      return _getFxFallback();
    }
  }

  Future<Map<String, double>> _getFxPrimary() async {
    final response = await _client
        .get(Uri.parse(RateConfig.fxUrl))
        .timeout(RateConfig.requestTimeout);
    if (response.statusCode != 200) {
      throw RateException('Currency feed returned ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    final rates = json is Map ? json['rates'] : null;
    if (rates is! Map) throw const RateException('Currency rates missing');
    final parsed = <String, double>{};
    for (final entry in rates.entries) {
      final value = _asDouble(entry.value);
      if (value != null && _isValid(value)) {
        parsed[entry.key.toString().toUpperCase()] = value;
      }
    }
    if (!_isValid(parsed['PKR'])) {
      throw const RateException('PKR missing in response');
    }
    return parsed;
  }

  Future<Map<String, double>> _getFxFallback() async {
    final response = await _client
        .get(Uri.parse(RateConfig.fxFallbackUrl))
        .timeout(RateConfig.requestTimeout);
    if (response.statusCode != 200) {
      throw RateException('Fallback feed returned ${response.statusCode}');
    }
    final json = jsonDecode(response.body);
    final usd = json is Map ? json['usd'] : null;
    if (usd is! Map) throw const RateException('Currency rates missing');
    final parsed = <String, double>{};
    for (final entry in usd.entries) {
      final value = _asDouble(entry.value);
      if (value != null && _isValid(value)) {
        parsed[entry.key.toString().toUpperCase()] = value;
      }
    }
    if (!_isValid(parsed['PKR'])) {
      throw const RateException('PKR missing in response');
    }
    return parsed;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _isValid(double? value) =>
      value != null && value.isFinite && value > 0;
}

// ---------------------------------------------------------------------------
// State: cache, refresh timing, history
// ---------------------------------------------------------------------------

class RateController extends ChangeNotifier {
  RateController({RateService? service}) : _service = service ?? RateService();

  static const _snapshotKey = 'mint.snapshot.v1';
  static const _historyKey = 'mint.history.v1';

  final RateService _service;

  MarketSnapshot? snapshot;
  Map<String, List<RatePoint>> history = {};
  bool isRefreshing = false;
  String? error;

  Timer? _timer;
  bool _foreground = true;
  bool _disposed = false;
  int _failures = 0;
  DateTime _nextAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastManual = DateTime.fromMillisecondsSinceEpoch(0);

  /// Loads saved data, refreshes once, then keeps refreshing while the app is
  /// in the foreground.
  Future<void> start() async {
    await _loadCache();
    if (_disposed) return;
    notifyListeners();
    await refresh(force: true);
    if (_disposed) return;
    _timer = Timer.periodic(RateConfig.goldRefresh, (_) {
      if (_foreground) refresh();
    });
  }

  void setForeground(bool value) {
    final resumed = value && !_foreground;
    _foreground = value;
    if (resumed) refresh();
  }

  /// Refresh button: ignores taps within a short cooldown.
  Future<void> refreshManual() async {
    final now = DateTime.now();
    if (now.difference(_lastManual) < RateConfig.manualCooldown) return;
    _lastManual = now;
    await refresh(force: true);
  }

  Future<void> refresh({bool force = false}) async {
    if (isRefreshing || _disposed) return;
    final now = DateTime.now();
    if (!force && now.isBefore(_nextAttempt)) return;

    isRefreshing = true;
    notifyListeners();
    try {
      final old = snapshot;
      final needFx =
          old == null ||
          now.difference(old.fxFetchedAt) >= RateConfig.fxRefresh;

      double? gold;
      Map<String, double>? fxRates;
      Object? failure;
      try {
        gold = await _service.fetchGoldUsdPerOz(previous: old?.goldUsdPerOz);
      } catch (e) {
        failure = e;
      }
      if (needFx) {
        try {
          fxRates = await _service.fetchUsdRates();
        } catch (e) {
          failure ??= e;
        }
      }

      final goldValue = gold ?? old?.goldUsdPerOz;
      final fxValue = fxRates?['PKR'] ?? old?.usdPkr;
      final currencyValues = fxRates ?? old?.usdRates;
      if (goldValue == null || fxValue == null || currencyValues == null) {
        throw failure ?? const RateException('No data');
      }

      if (gold != null || fxRates != null) {
        final fetchedAt = DateTime.now();
        final next = MarketSnapshot(
          goldUsdPerOz: goldValue,
          usdPkr: fxValue,
          usdRates: currencyValues,
          goldFetchedAt: gold != null ? fetchedAt : old!.goldFetchedAt,
          fxFetchedAt: fxRates != null ? fetchedAt : old!.fxFetchedAt,
        );
        snapshot = next;
        _record(next, fetchedAt);
        await _save();
      }

      if (failure == null) {
        error = null;
        _failures = 0;
        _nextAttempt = DateTime.now();
      } else {
        _registerFailure(partial: true);
      }
    } catch (_) {
      _registerFailure(partial: false);
    } finally {
      isRefreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _registerFailure({required bool partial}) {
    _failures++;
    final seconds = math.min(900, 60 * (1 << (math.min(_failures, 5) - 1)));
    _nextAttempt = DateTime.now().add(Duration(seconds: seconds));
    if (snapshot == null) {
      error = "Couldn't load rates. Check your connection and try again.";
    } else if (partial) {
      error = "Couldn't refresh some rates. Showing the latest saved values.";
    } else {
      error = "Couldn't refresh rates. Showing the last saved prices.";
    }
  }

  // ----- history -----------------------------------------------------------

  void _record(MarketSnapshot s, DateTime time) {
    _append('gold', s.gold24kPkrPerTola, time);
    _append('usd', s.usdPkr, time);
    _append('sar', s.sarPkr, time);
    for (final code in supportedCurrencyCodes.skip(1)) {
      final value = s.pkrPerCurrency(code);
      if (value > 0) {
        _append(code.toLowerCase(), code == 'KRW' ? value * 1000 : value, time);
      }
    }
  }

  void _append(String id, double value, DateTime time) {
    final list = List<RatePoint>.of(history[id] ?? const <RatePoint>[]);
    if (list.isNotEmpty &&
        time.difference(list.last.time) < RateConfig.historyInterval) {
      return;
    }
    list.add(RatePoint(time, value));
    history[id] = _compact(list, time);
  }

  /// Keeps every point from the last 7 days, and one point per day before that.
  List<RatePoint> _compact(List<RatePoint> points, DateTime now) {
    final cutoff = now.subtract(const Duration(days: 7));
    final recent = <RatePoint>[];
    final daily = <String, RatePoint>{};
    for (final point in points) {
      if (point.time.isAfter(cutoff)) {
        recent.add(point);
      } else {
        daily['${point.time.year}-${point.time.month}-${point.time.day}'] =
            point;
      }
    }
    final older = daily.values.toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return [...older, ...recent];
  }

  /// Values for the chart, oldest first, within the selected range.
  List<double> chartValues(String id, String range) {
    const days = {'1W': 7, '1M': 30, '3M': 90, '1Y': 365};
    final cutoff = DateTime.now().subtract(Duration(days: days[range] ?? 7));
    return [
      for (final point in history[id] ?? const <RatePoint>[])
        if (point.time.isAfter(cutoff)) point.value,
    ];
  }

  /// Last recorded value of each day, oldest first.
  List<DayClose> dailyCloses(String id) {
    final byDay = <String, RatePoint>{};
    for (final point in history[id] ?? const <RatePoint>[]) {
      byDay['${point.time.year}-${point.time.month}-${point.time.day}'] = point;
    }
    return byDay.values
        .map(
          (p) => DayClose(
            DateTime(p.time.year, p.time.month, p.time.day),
            p.value,
          ),
        )
        .toList();
  }

  // ----- storage -----------------------------------------------------------

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_snapshotKey);
      if (saved != null) {
        snapshot = MarketSnapshot.fromJson(
          jsonDecode(saved) as Map<String, dynamic>,
        );
      }
      final savedHistory = prefs.getString(_historyKey);
      if (savedHistory != null) {
        final decoded = jsonDecode(savedHistory) as Map<String, dynamic>;
        history = decoded.map(
          (key, value) => MapEntry(
            key,
            (value as List)
                .map((e) => RatePoint.fromJson(e as List<dynamic>))
                .toList(),
          ),
        );
      }
    } catch (_) {
      // Corrupt or missing cache: start fresh.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = snapshot;
      if (s != null) {
        await prefs.setString(_snapshotKey, jsonEncode(s.toJson()));
      }
      await prefs.setString(
        _historyKey,
        jsonEncode(
          history.map(
            (key, value) =>
                MapEntry(key, value.map((p) => p.toJson()).toList()),
          ),
        ),
      );
    } catch (_) {
      // Saving is best-effort.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _service.close();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Turning raw data into what the screens display
// ---------------------------------------------------------------------------

List<Rate> buildRates({
  required MarketSnapshot? snapshot,
  required Map<String, List<RatePoint>> history,
  DateTime? now,
}) {
  final s = snapshot;
  if (s == null) return placeholderRates;
  final clock = now ?? DateTime.now();

  Rate make({
    required String id,
    required String code,
    required String name,
    required double amount,
    required int decimals,
    required String unit,
    required bool isGold,
    required DateTime updatedAt,
    required Duration staleAfter,
  }) {
    final previous = previousDayClose(
      history[id] ?? const <RatePoint>[],
      clock,
    );
    final pct = previous == null || previous == 0
        ? null
        : (amount - previous) / previous * 100;
    return Rate(
      id: id,
      code: code,
      name: name,
      value: 'Rs ${formatPkr(amount, decimals: decimals)}',
      unit: unit,
      change: pct == null ? '—' : '${pct.abs().toStringAsFixed(2)}%',
      isUp: pct == null || pct >= 0,
      isGold: isGold,
      amount: amount,
      updatedAt: updatedAt,
      isStale: clock.difference(updatedAt) > staleAfter,
    );
  }

  return [
    make(
      id: 'gold',
      code: 'Au',
      name: 'Gold 24K',
      amount: s.gold24kPkrPerTola,
      decimals: 0,
      unit: '/ tola',
      isGold: true,
      updatedAt: s.goldFetchedAt,
      staleAfter: RateConfig.goldStaleAfter,
    ),
    make(
      id: 'usd',
      code: '\$',
      name: 'US Dollar',
      amount: s.usdPkr,
      decimals: 2,
      unit: '/ 1 USD',
      isGold: false,
      updatedAt: s.fxFetchedAt,
      staleAfter: RateConfig.fxStaleAfter,
    ),
    ...[
      ('sar', 'SR', 'Saudi Riyal', 'SAR', 2, '/ 1 SAR'),
      ('aed', 'AED', 'UAE Dirham', 'AED', 2, '/ 1 AED'),
      ('eur', '€', 'Euro', 'EUR', 2, '/ 1 EUR'),
      ('gbp', '£', 'British Pound', 'GBP', 2, '/ 1 GBP'),
      ('krw', '₩', 'South Korean Won', 'KRW', 4, '/ 1,000 KRW'),
      ('jpy', '¥', 'Japanese Yen', 'JPY', 2, '/ 1 JPY'),
      ('cad', 'C\$', 'Canadian Dollar', 'CAD', 2, '/ 1 CAD'),
      ('aud', 'A\$', 'Australian Dollar', 'AUD', 2, '/ 1 AUD'),
    ].map(
      (item) => make(
        id: item.$1,
        code: item.$2,
        name: item.$3,
        amount: item.$1 == 'krw'
            ? s.pkrPerCurrency(item.$4) * 1000
            : s.pkrPerCurrency(item.$4),
        decimals: item.$5,
        unit: item.$6,
        isGold: false,
        updatedAt: s.fxFetchedAt,
        staleAfter: RateConfig.fxStaleAfter,
      ),
    ),
  ];
}

/// The last value recorded before today, used for the "% today" change.
double? previousDayClose(List<RatePoint> points, DateTime now) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  for (var i = points.length - 1; i >= 0; i--) {
    if (points[i].time.isBefore(startOfToday)) return points[i].value;
  }
  return null;
}

/// Keeps charts light by thinning very long series.
List<double> downsample(List<double> values, int maxPoints) {
  if (values.length <= maxPoints) return values;
  return [
    for (var i = 0; i < maxPoints; i++)
      values[(i * (values.length - 1) / (maxPoints - 1)).round()],
  ];
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

String formatPkr(double value, {int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  if (parts.length > 1) buffer.write('.${parts[1]}');
  return buffer.toString();
}

String timeAgo(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String dateLine(DateTime now) =>
    '${_weekdays[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day}, ${now.year}';

String greeting(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String dayLabel(DateTime date, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  return '${_months[date.month - 1].substring(0, 3)} ${date.day}';
}
