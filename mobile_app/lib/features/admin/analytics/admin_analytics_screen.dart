import 'package:flutter/material.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../../../core/services/admin_api_service.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  // TODO: Fetch from AdminApiService
  bool _isLoading = false; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analytics Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatCard("Total Active Users", "3,450", "+12%"),
            const SizedBox(height: 16),
            _buildStatCard("Monthly Revenue", "\$12,400", "+8%"),
            const SizedBox(height: 16),
            _buildStatCard("Conversion Rate", "4.2%", "-1%"),
            const SizedBox(height: 32),
            const Text("Detailed Charts Coming Soon"),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String growth) {
    final isPositive = growth.startsWith('+');
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.displaySmall),
            ],
          ),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: isPositive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
               borderRadius: BorderRadius.circular(20),
             ),
             child: Text(growth, style: TextStyle(color: isPositive ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}
