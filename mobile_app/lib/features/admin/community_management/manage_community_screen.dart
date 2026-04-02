import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'manage_polls_screen.dart';
import 'manage_quizzes_screen.dart';

class ManageCommunityScreen extends StatelessWidget {
  const ManageCommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("MANAGE COMMUNITY", style: GoogleFonts.lato(letterSpacing: 2, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _buildManagementTile(
            context,
            icon: Icons.poll_outlined,
            title: "Manage Polls",
            description: "Create and edit community polls to gather founder insights.",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagePollsScreen())),
          ),
          const SizedBox(height: 12),
          _buildManagementTile(
            context,
            icon: Icons.quiz_outlined,
            title: "Manage Quizzes",
            description: "Update interactive quizzes and test founder knowledge.",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageQuizzesScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Icon(
                  icon, 
                  color: isDark ? Theme.of(context).colorScheme.secondary : Theme.of(context).primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lato(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
