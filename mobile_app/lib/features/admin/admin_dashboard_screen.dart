import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_management_screen.dart';
import 'resource_management_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ADMIN DASHBOARD", style: GoogleFonts.lato(letterSpacing: 2, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAdminTile(
            context,
            icon: Icons.people_outline,
            title: "Manage Users",
            subtitle: "View, edit, and delete users",
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const UserManagementScreen()));
            },
          ),
          _buildAdminTile(
            context,
            icon: Icons.library_books_outlined,
            title: "Manage Resources",
            subtitle: "Magazines, Masterclasses, Newsletters",
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ResourceManagementScreen()));
            },
          ),
          // Add more admin tools here
        ],
      ),
    );
  }

  Widget _buildAdminTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
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
}
