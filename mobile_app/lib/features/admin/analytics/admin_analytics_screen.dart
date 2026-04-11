import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/admin_api_service.dart';
import '../../../core/theme/ffig_theme.dart';
import 'event_revenue_screen.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final AdminApiService _apiService = AdminApiService();

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _apiService.fetchAnalytics();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'NGN':
        return '₦';
      case 'KES':
        return 'KSh ';
      case 'ZAR':
        return 'R ';
      default:
        return '$code ';
    }
  }

  String _formatMoney(double amount, String currencyCode) {
    final symbol = _getCurrencySymbol(currencyCode);
    final compact = NumberFormat.compact().format(amount);
    return '$symbol$compact';
  }

  String _safePercent(dynamic value) {
    final raw = value?.toString() ?? '0%';
    return raw.contains('%') ? raw : '$raw%';
  }

  String _shortDateLabel(String rawDay) {
    try {
      return DateFormat('dd MMM').format(DateTime.parse(rawDay).toLocal());
    } catch (_) {
      return rawDay;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        appBar: _AnalyticsAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: const _AnalyticsAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 46, color: Colors.red),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = _data;
    if (data == null) {
      return Scaffold(
        appBar: const _AnalyticsAppBar(),
        body: Center(
          child: ElevatedButton(
            onPressed: _loadData,
            child: const Text('Load Analytics'),
          ),
        ),
      );
    }

    final activeUsers = data['active_users'] as Map<String, dynamic>? ?? {};
    final userTiers = data['user_tiers'] as Map<String, dynamic>? ?? {};
    final conversion = data['conversion_rates'] as Map<String, dynamic>? ?? {};
    final revenue = data['revenue'] as Map<String, dynamic>? ?? {};

    final totalUsers = _asInt(activeUsers['monthly']);
    final activeNow = _asInt(activeUsers['daily']);
    final freeCount = _asInt(userTiers['free']);
    final standardCount = _asInt(userTiers['standard']);
    final premiumCount = _asInt(userTiers['premium']);

    final primaryCurrency = (revenue['currency'] ?? 'USD').toString();
    final totalRevenue = _asDouble(revenue['total']);
    final eventsRevenue = _asDouble(revenue['events']);

    return Scaffold(
      appBar: const _AnalyticsAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _KpiTile(
                  title: 'Total Members',
                  value: NumberFormat.decimalPattern().format(totalUsers),
                  subtitle: 'All registered users',
                  color: const Color(0xFF1E88E5),
                ),
                _KpiTile(
                  title: 'Active Accounts',
                  value: NumberFormat.decimalPattern().format(activeNow),
                  subtitle: 'Currently active users',
                  color: const Color(0xFF43A047),
                ),
                _KpiTile(
                  title: 'Free -> Standard',
                  value: _safePercent(conversion['free_to_standard']),
                  subtitle: 'Conversion rate',
                  color: const Color(0xFF6D4C41),
                ),
                _KpiTile(
                  title: 'Standard -> Premium',
                  value: _safePercent(conversion['standard_to_premium']),
                  subtitle: 'Conversion rate',
                  color: const Color(0xFFF9A825),
                ),
                _KpiTile(
                  title: 'Revenue (${primaryCurrency.toUpperCase()})',
                  value: _formatMoney(totalRevenue, primaryCurrency),
                  subtitle: 'Event revenue tracked',
                  color: FfigTheme.primaryBrown,
                  wide: true,
                ),
                _KpiTile(
                  title: 'Events Revenue',
                  value: _formatMoney(eventsRevenue, primaryCurrency),
                  subtitle: 'From ticket sales',
                  color: Colors.deepPurple,
                  wide: true,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildMultiCurrencyRow(revenue),
            const SizedBox(height: 18),
            _ChartCard(
              title: 'Member Composition',
              subtitle: 'Tier mix across Free, Standard, and Premium members.',
              child: _buildUserTierChart(
                freeCount: freeCount,
                standardCount: standardCount,
                premiumCount: premiumCount,
              ),
            ),
            const SizedBox(height: 18),
            _ChartCard(
              title: 'Member Growth (30 Days)',
              subtitle: 'Daily new-user signups over the last 30 days.',
              child: _buildGrowthChart(),
            ),
            const SizedBox(height: 18),
            _ChartCard(
              title: 'Top Revenue Events',
              subtitle: 'Best-performing events by ticket revenue.',
              trailing: TextButton(
                onPressed: () {
                  final perEvent = revenue['per_event'];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EventRevenueScreen(
                        eventData: perEvent is List<dynamic> ? perEvent : [],
                      ),
                    ),
                  );
                },
                child: const Text('View Full Breakdown'),
              ),
              child: _buildRevenueBarChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiCurrencyRow(Map<String, dynamic> revenue) {
    final byCurrencyRaw = revenue['by_currency'];
    if (byCurrencyRaw is! List || byCurrencyRaw.isEmpty) {
      return const SizedBox.shrink();
    }

    final byCurrency = byCurrencyRaw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: byCurrency.map((row) {
          final code = (row['currency'] ?? 'USD').toString().toUpperCase();
          final total = _asDouble(row['total']);
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: FfigTheme.primaryBrown.withOpacity(0.08),
              border: Border.all(color: FfigTheme.primaryBrown.withOpacity(0.2)),
            ),
            child: Text(
              '$code: ${_formatMoney(total, code)}',
              style: const TextStyle(
                color: FfigTheme.primaryBrown,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserTierChart({
    required int freeCount,
    required int standardCount,
    required int premiumCount,
  }) {
    final total = freeCount + standardCount + premiumCount;
    if (total == 0) {
      return const SizedBox(
        height: 190,
        child: Center(child: Text('No user tier data yet.')),
      );
    }

    double percent(int count) => total == 0 ? 0 : ((count / total) * 100);

    final sections = [
      _TierSlice('Free', freeCount, const Color(0xFF9E9E9E)),
      _TierSlice('Standard', standardCount, FfigTheme.primaryBrown),
      _TierSlice('Premium', premiumCount, const Color(0xFFFFB300)),
    ];

    return SizedBox(
      height: 230,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    centerSpaceRadius: 44,
                    sectionsSpace: 3,
                    sections: sections.map((slice) {
                      final p = percent(slice.count);
                      return PieChartSectionData(
                        value: slice.count.toDouble(),
                        color: slice.color,
                        radius: slice.label == 'Premium' ? 54 : 48,
                        title: p >= 8 ? '${p.toStringAsFixed(0)}%' : '',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      NumberFormat.decimalPattern().format(total),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: sections.map((slice) {
                final p = percent(slice.count);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: slice.color,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${slice.label}: ${NumberFormat.decimalPattern().format(slice.count)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${p.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthChart() {
    final growthRaw = _data?['user_growth'];
    if (growthRaw is! List || growthRaw.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No signup growth data found.')),
      );
    }

    final growth = growthRaw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    final spots = <FlSpot>[];
    double maxY = 0;
    for (var i = 0; i < growth.length; i++) {
      final count = _asDouble(growth[i]['count']);
      spots.add(FlSpot(i.toDouble(), count));
      if (count > maxY) maxY = count;
    }
    final double topY = math.max(4.0, maxY * 1.25);
    final yInterval = math.max(1, (topY / 4).ceil()).toDouble();
    final midIndex = growth.length > 1 ? ((growth.length - 1) / 2).round() : 0;
    final lastIndex = growth.length - 1;

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: lastIndex.toDouble(),
          minY: 0,
          maxY: topY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.15),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i != 0 && i != midIndex && i != lastIndex) {
                    return const SizedBox.shrink();
                  }
                  if (i < 0 || i >= growth.length) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      _shortDateLabel((growth[i]['day'] ?? '').toString()),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final i = spot.x.round();
                  final dayRaw = (i >= 0 && i < growth.length) ? (growth[i]['day'] ?? '').toString() : '';
                  return LineTooltipItem(
                    '${_shortDateLabel(dayRaw)}\n',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    children: [
                      TextSpan(
                        text: '${spot.y.toInt()} signups',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: FfigTheme.primaryBrown,
              barWidth: 3.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    FfigTheme.primaryBrown.withOpacity(0.2),
                    FfigTheme.primaryBrown.withOpacity(0.01),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueBarChart() {
    final revenueRaw = _data?['revenue'];
    if (revenueRaw is! Map) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No revenue data available.')),
      );
    }

    final perEventRaw = revenueRaw['per_event'];
    if (perEventRaw is! List || perEventRaw.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('No event revenue records yet.')),
      );
    }

    final eventData = perEventRaw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    eventData.sort((a, b) => _asDouble(b['revenue']).compareTo(_asDouble(a['revenue'])));
    final displayData = eventData.take(6).toList();
    final maxRevenue = displayData.fold<double>(0, (m, e) => math.max(m, _asDouble(e['revenue'])));
    final double topY = math.max(10.0, maxRevenue * 1.25);

    return SizedBox(
      height: 280,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: topY,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: math.max(1, (topY / 4)).toDouble(),
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withOpacity(0.14),
              strokeWidth: 1,
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final row = displayData[groupIndex];
                final currency = (row['currency'] ?? 'USD').toString();
                final eventName = (row['event'] ?? 'Event').toString();
                return BarTooltipItem(
                  '$eventName\n${_getCurrencySymbol(currency)}${rod.toY.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  final primary = (displayData.isNotEmpty ? displayData.first['currency'] : 'USD').toString();
                  return Text(
                    _formatMoney(value, primary),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 66,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= displayData.length) return const SizedBox.shrink();
                  final raw = (displayData[i]['event'] ?? '').toString();
                  final name = raw.length > 14 ? '${raw.substring(0, 14)}..' : raw;
                  return SideTitleWidget(
                    meta: meta,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(displayData.length, (i) {
            final revenue = _asDouble(displayData[i]['revenue']);
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: revenue,
                  width: 20,
                  borderRadius: BorderRadius.circular(5),
                  color: FfigTheme.primaryBrown,
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: topY,
                    color: FfigTheme.primaryBrown.withOpacity(0.09),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _AnalyticsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AnalyticsAppBar();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Analytics Dashboard'),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _KpiTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final bool wide;

  const _KpiTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tileWidth = wide ? screenWidth - 32 : (screenWidth - 42) / 2;

    return Container(
      width: tileWidth,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).cardColor,
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).cardColor,
        border: Border.all(color: Colors.grey.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TierSlice {
  final String label;
  final int count;
  final Color color;

  _TierSlice(this.label, this.count, this.color);
}
