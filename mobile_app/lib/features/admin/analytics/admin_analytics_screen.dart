import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/services/admin_api_service.dart';
import 'event_revenue_screen.dart';

/// A dashboard for Admin-level analytics.
///
/// **Features:**
/// - Displays high-level stats: Active Users, Revenue, Conversion Rates.
/// - Fetches data from `AdminApiService.fetchAnalytics`.
/// - Shows placeholders for detailed charts (future implementation).
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = false;
  final _apiService = AdminApiService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Fetches analytics data from the backend.
  /// - Sets `_isLoading` while fetching.
  /// - Handles errors with a SnackBar.
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.fetchAnalytics();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analytics Dashboard")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_data != null) ...[
                    _buildStatCard(
                      "Total Active Users",
                      "${_data!['active_users']['monthly']}",
                      "+${_data!['active_users']['daily']} Daily",
                    ),
                    const SizedBox(height: 16),
                    _buildRevenueSection(),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      "Conversion Rate",
                      "${_data!['conversion_rates']['standard_to_premium']}",
                      "Free->Std: ${_data!['conversion_rates']['free_to_standard']}",
                    ),
                    const SizedBox(height: 32),
                    const SizedBox(height: 24),
                    _buildSectionTitle("User Composition"),
                    const SizedBox(height: 16),
                    _buildUserTierChart(),
                    const SizedBox(height: 32),
                    _buildSectionTitle("Member Growth (30 Days)"),
                    const SizedBox(height: 16),
                    _buildGrowthChart(),
                    const SizedBox(height: 32),
                    _buildSectionTitle("Revenue by Event"),
                    const SizedBox(height: 16),
                    _buildRevenueBarChart(),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildRevenueSection() {
    final revenue = _data!['revenue'];
    final byCurrency = revenue['by_currency'] as List<dynamic>;
    final primaryCurrency = revenue['currency'] ?? 'USD';
    final primaryValue = revenue['total'] ?? 0.0;

    return Column(
      children: [
        _buildStatCard(
          "Total Revenue ($primaryCurrency)",
          "${_getCurrencySymbol(primaryCurrency)}${primaryValue.toStringAsFixed(2)}",
          "Events: ${_getCurrencySymbol(primaryCurrency)}${(revenue['events'] ?? 0.0).toStringAsFixed(2)}",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventRevenueScreen(
                  eventData: revenue['per_event'] is List<dynamic> ? revenue['per_event'] as List<dynamic> : [],
                ),
              ),
            );
          },
        ),
        if (byCurrency.length > 1) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: byCurrency.where((c) => c['currency'] != primaryCurrency).map((c) {
                final code = c['currency'] as String;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: FfigTheme.primaryBrown.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$code: ${_getCurrencySymbol(code)}${(c['total'] as double).toStringAsFixed(2)}",
                    style: const TextStyle(color: FfigTheme.primaryBrown, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'USD': return r'$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'NGN': return '₦';
      case 'KES': return 'KSh ';
      case 'ZAR': return 'R ';
      default: return '$code ';
    }
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildUserTierChart() {
    final tiers = _data!['user_tiers'];
    final total = tiers['free'] + tiers['standard'] + tiers['premium'];
    if (total == 0) return const Center(child: Text("No user data"));

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    value: (tiers['free'] as int).toDouble(),
                    title: '',
                    color: Colors.grey.withOpacity(0.5),
                    radius: 12,
                  ),
                  PieChartSectionData(
                    value: (tiers['standard'] as int).toDouble(),
                    title: '',
                    color: FfigTheme.primaryBrown,
                    radius: 15,
                  ),
                  PieChartSectionData(
                    value: (tiers['premium'] as int).toDouble(),
                    title: '',
                    color: Colors.amber,
                    radius: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendRow("Free", Colors.grey, tiers['free']),
              _buildLegendRow("Standard", FfigTheme.primaryBrown, tiers['standard']),
              _buildLegendRow("Premium", Colors.amber, tiers['premium']),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, Color color, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text("$label: $value", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGrowthChart() {
    final List<dynamic> growth = _data!['user_growth'] ?? [];
    if (growth.isEmpty) return const Center(child: Text("No growth data"));

    return Container(
       height: 250,
       padding: const EdgeInsets.fromLTRB(8, 24, 24, 8),
       decoration: BoxDecoration(
         color: Theme.of(context).cardColor,
         borderRadius: BorderRadius.circular(16),
         boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
       ),
       child: LineChart(
          LineChartData(
            lineTouchData: const LineTouchData(enabled: true),
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double v, TitleMeta m) {
                    if (v.toInt() % 10 != 0) return const SizedBox.shrink();
                    return SideTitleWidget(
                      space: 4,
                      meta: m,
                      child: Text("${v.toInt()}d", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    );
                  }
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                isCurved: true,
                color: FfigTheme.primaryBrown,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [FfigTheme.primaryBrown.withOpacity(0.3), FfigTheme.primaryBrown.withOpacity(0.0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                spots: List.generate(growth.length, (i) => FlSpot(i.toDouble(), (growth[i]['count'] as int).toDouble())),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildRevenueBarChart() {
    final List<dynamic> eventData = _data!['revenue']['per_event'] ?? [];
    if (eventData.isEmpty) return const Center(child: Text("No revenue data"));
    
    // Take top 5 for simplicity on dashboard
    final displayData = eventData.take(5).toList();
    double maxRevenue = displayData.fold(0.0, (m, e) => (e['revenue'] as double) > m ? e['revenue'] : m);

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxRevenue > 0 ? maxRevenue * 1.2 : 100,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final currency = displayData[groupIndex]["currency"] ?? 'USD';
                return BarTooltipItem(
                  '${displayData[groupIndex]["event"]}\n${_getCurrencySymbol(currency)}${rod.toY.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                );
              },
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (double v, TitleMeta m) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= displayData.length) return const SizedBox.shrink();
                  String t = displayData[idx]['event'] ?? '';
                  if (t.length > 12) t = "${t.substring(0, 10)}..";
                  return SideTitleWidget(
                    space: 8,
                    meta: m,
                    child: RotatedBox(
                      quarterTurns: 0,
                      child: Text(
                        t,
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
              )
            )
          ),
          barGroups: List.generate(displayData.length, (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (displayData[i]['revenue'] as double),
                color: FfigTheme.primaryBrown,
                width: 24,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxRevenue > 0 ? maxRevenue * 1.2 : 100,
                  color: FfigTheme.primaryBrown.withOpacity(0.05),
                ),
              )
            ],
          )),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    // Determine color based on context (simple logic for now)
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: Theme.of(
                      context,
                    ).textTheme.displaySmall?.copyWith(fontSize: 32),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: FfigTheme.primaryBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: FfigTheme.primaryBrown,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
