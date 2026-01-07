import 'package:flutter/material.dart';
import '../models/founder_profile.dart';

class FounderCard extends StatelessWidget {
  final FounderProfile profile;

  const FounderCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goldColor = const Color(0xFFD4AF37);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
           // Navigation placeholder
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Avatar + Name + Business
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                   // Avatar
                   Container(
                     padding: const EdgeInsets.all(2),
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       border: Border.all(color: goldColor, width: 2),
                     ),
                     child: CircleAvatar(
                       radius: 30,
                       backgroundColor: Colors.grey[200],
                       backgroundImage: NetworkImage(profile.photoUrl),
                       onBackgroundImageError: (_, __) {},
                       child: profile.photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                     ),
                   ),
                   const SizedBox(width: 16),
                   // Text Info
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                             Flexible(
                               child: Text(
                                 profile.name,
                                 style: theme.textTheme.titleLarge?.copyWith(
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                             ),
                             if (profile.isPremium) ...[
                               const SizedBox(width: 6),
                               Icon(Icons.verified, color: goldColor, size: 18),
                             ]
                           ],
                         ),
                         const SizedBox(height: 4),
                         Text(
                           profile.businessName.toUpperCase(),
                           style: TextStyle(
                             color: goldColor,
                             fontWeight: FontWeight.bold,
                             fontSize: 12,
                             letterSpacing: 1.0,
                           ),
                         ),
                         const SizedBox(height: 4),
                         Row(
                           children: [
                             Icon(Icons.location_on, size: 12, color: theme.hintColor),
                             const SizedBox(width: 4),
                             Text(
                               profile.country, 
                               style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                             ),
                           ],
                         )
                       ],
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 16),
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: goldColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: goldColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: goldColor, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      "FOUNDER OF THE WEEK",
                      style: TextStyle(color: goldColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // BIO
              Text(
                profile.bio,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
