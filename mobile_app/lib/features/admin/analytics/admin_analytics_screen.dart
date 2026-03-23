import 'package:flutter/material.dart';
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
                    _buildStatCard(
                      "Total Revenue",
                      "\$${_data!['revenue']['total']}",
                      "Events: \$${_data!['revenue']['events']}",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EventRevenueScreen(
                              eventData:
                                  _data!['revenue']['per_event']
                                      is List<dynamic>
                                  ? _data!['revenue']['per_event']
                                        as List<dynamic>
                                  : [],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildStatCard(
                      "Conversion Rate",
                      "${_data!['conversion_rates']['standard_to_premium']}",
                      "Free->Std: ${_data!['conversion_rates']['free_to_standard']}",
                    ),
                    const SizedBox(height: 32),
                  ],
                  const Text("Detailed Charts Coming Soon"),
                ],
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
