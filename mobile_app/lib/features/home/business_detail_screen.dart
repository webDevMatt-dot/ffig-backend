import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared_widgets/user_avatar.dart';
import 'models/business_profile.dart';

class BusinessDetailScreen extends StatelessWidget {
  final BusinessProfile profile;

  const BusinessDetailScreen({super.key, required this.profile});

  Future<void> _launchURL() async {
    final Uri url = Uri.parse(profile.website);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(profile.name),
        actions: [
          if (profile.isPremium)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.verified, color: Colors.blue),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Business Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue, width: 3),
                    ),
                    child: UserAvatar(
                      radius: 60,
                      imageUrl: profile.imageUrl,
                      firstName: profile.name[0],
                      lastName: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile.name,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, size: 16, color: theme.hintColor),
                      const SizedBox(width: 4),
                      Text(profile.location, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Description Section
            Text(
              "About the Business",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              profile.description,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
            
            const SizedBox(height: 32),
            
            // Website Button
            if (profile.website.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _launchURL,
                  icon: const Icon(Icons.language),
                  label: const Text("Visit Website"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            
            const SizedBox(height: 48),
            
            // Owner Section
            if (profile.ownerName != null) ...[
              const Divider(),
              const SizedBox(height: 24),
              Text(
                "Meet the Owner",
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      radius: 30,
                      imageUrl: profile.ownerPhoto ?? '',
                      firstName: profile.ownerName![0],
                      lastName: '',
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.ownerName!,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Visionary behind ${profile.name}",
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
