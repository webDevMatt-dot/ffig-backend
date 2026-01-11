import 'package:flutter/material.dart';
import '../../../../core/theme/ffig_theme.dart';

class AdminApprovalsScreen extends StatelessWidget {
  const AdminApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Approvals Center"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Business Profiles"),
              Tab(text: "Marketing Requests"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBusinessList(),
            _buildMarketingList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessList() {
    return const Center(child: Text("Pending Business Profiles will appear here"));
  }

  Widget _buildMarketingList() {
    return const Center(child: Text("Pending Ads & Promos will appear here"));
  }
}
