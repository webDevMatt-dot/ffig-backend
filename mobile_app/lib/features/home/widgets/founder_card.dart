import 'package:flutter/material.dart';
import '../models/founder_profile.dart';

class FounderCard extends StatelessWidget {
  final FounderProfile profile;

  const FounderCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        onTap: () {
          // Navigate to Founder Detail
          print("Navigate to Founder: ${profile.name}");
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(
                  profile.photoUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(child: Icon(Icons.person, size: 50, color: Colors.grey)),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "FOUNDER OF THE WEEK",
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        profile.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (profile.isPremium)
                        const Icon(Icons.diamond, color: Colors.amber, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.businessName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(profile.country, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
