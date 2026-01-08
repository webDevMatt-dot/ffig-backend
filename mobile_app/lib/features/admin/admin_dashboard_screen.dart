import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_management_screen.dart';
import 'resource_management_screen.dart';
// Import Management Screens
import 'home_management/manage_hero_screen.dart';
import 'home_management/manage_founder_screen.dart';
import 'home_management/manage_alerts_screen.dart';
import 'home_management/manage_ticker_screen.dart';
import 'events_management/manage_events_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if wide screen (Desktop/Web)
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text("ADMIN DASHBOARD", style: GoogleFonts.lato(letterSpacing: 2, fontWeight: FontWeight.bold)),
      ),
      body: isWide 
        ? _buildWideLayout(context) 
        : _buildMobileLayout(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(context, "General Management"),
        _buildAdminTile(
          context,
          icon: Icons.people_outline,
          title: "Manage Users",
          subtitle: "View, edit, and delete users",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen())),
        ),
        _buildAdminTile(
          context,
          icon: Icons.library_books_outlined,
          title: "Manage Resources",
          subtitle: "Magazines, Masterclasses, Newsletters",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ResourceManagementScreen())),
        ),
        _buildAdminTile(
          context,
          icon: Icons.event,
          title: "Manage Events",
          subtitle: "Create, edit, and ticket events",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageEventsScreen())),
        ),
        
        const SizedBox(height: 24),
        _buildSectionHeader(context, "Homepage Content"),
        
        _buildAdminTile(
          context,
          icon: Icons.view_carousel_outlined,
          title: "Hero Carousel",
          subtitle: "Manage rotating hero banners",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageHeroScreen())),
        ),
        _buildAdminTile(
          context,
          icon: Icons.star_border,
          title: "Founder Spotlight",
          subtitle: "Update the Founder of the Week",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageFounderScreen())),
        ),
        _buildAdminTile(
          context,
          icon: Icons.campaign_outlined,
          title: "Flash Alerts",
          subtitle: "Create time-sensitive banners",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageAlertsScreen())),
        ),
         _buildAdminTile(
          context,
          icon: Icons.newspaper_outlined,
          title: "News Ticker",
          subtitle: "Update scrolling news items",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageTickerScreen())),
        ),
      ],
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Welcome, Admin.", style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 32),
          
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.5,
              children: [
                 _buildWideTile(
                  context, 
                  "Manage Users", 
                  Icons.people_outline, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen()))
                ),
                 _buildWideTile(
                  context, 
                  "Resources", 
                  Icons.library_books_outlined, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ResourceManagementScreen()))
                ),
                 _buildWideTile(
                  context, 
                  "Events", 
                  Icons.event, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageEventsScreen()))
                ),
                 _buildWideTile(
                  context, 
                  "Hero Carousel", 
                  Icons.view_carousel_outlined, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageHeroScreen()))
                ),
                 _buildWideTile(
                  context, 
                  "Founder Spotlight", 
                  Icons.star_border, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageFounderScreen()))
                ),
                 _buildWideTile(
                  context, 
                  "Flash Alerts", 
                  Icons.campaign_outlined, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageAlertsScreen()))
                ),
                 _buildWideTile(
                  context, 
                  "News Ticker", 
                  Icons.newspaper_outlined, 
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageTickerScreen()))
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
    );
  }

  Widget _buildAdminTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(icon, color: Theme.of(context).primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildWideTile(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
