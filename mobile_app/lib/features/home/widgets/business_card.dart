import 'package:flutter/material.dart';
import '../../../../shared_widgets/user_avatar.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../models/business_profile.dart';

/// Displays a detailed card for the "Business of the Month".
/// - Shows Logo, Name, Location, Description, and Website link.
class BusinessCard extends StatelessWidget {
  final BusinessProfile profile;

  const BusinessCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Define colors relative to Theme
    final cardColor = theme.cardColor;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final shadowColor = isDark ? Colors.transparent : Colors.black.withOpacity(0.05);
    final badgeBg = isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1);
    final badgeText = Colors.blue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
           // Navigation placeholder or launchUrl for website
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               // Header: Logo + Info
               Row(
                 children: [
                   Container(
                     padding: const EdgeInsets.all(2),
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       border: Border.all(color: Colors.blue, width: 2),
                     ),
                     child: UserAvatar(
                       radius: 28,
                       imageUrl: profile.imageUrl,
                       firstName: profile.name.isNotEmpty ? profile.name[0] : 'B',
                       lastName: '',
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                             Flexible(
                               child: Text(
                                 profile.name, 
                                 style: theme.textTheme.titleMedium?.copyWith(
                                   fontWeight: FontWeight.bold,
                                   fontSize: 18,
                                 ),
                               ),
                             ),
                             if (profile.isPremium) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Colors.blue, size: 16),
                             ]
                           ],
                         ),
                         const SizedBox(height: 4),
                         if (profile.location.isNotEmpty)
                         Row(
                           children: [
                             Icon(Icons.location_on_outlined, size: 14, color: theme.hintColor),
                             const SizedBox(width: 4),
                             Text(
                               profile.location, 
                               style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                             ),
                           ],
                         ),
                         if (profile.website.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Icon(Icons.language, size: 14, color: theme.primaryColor),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    profile.website,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.primaryColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                       ],
                     ),
                   ),
                 ],
               ),
               
               const SizedBox(height: 16),
               
               // Badge
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                 decoration: BoxDecoration(
                   color: badgeBg,
                   borderRadius: BorderRadius.circular(20),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(Icons.storefront, color: badgeText, size: 16),
                     const SizedBox(width: 6),
                     Text(
                       "BUSINESS OF THE MONTH",
                       style: TextStyle(
                         color: badgeText, 
                         fontSize: 11, 
                         fontWeight: FontWeight.bold, 
                         letterSpacing: 0.5
                       ),
                     ),
                   ],
                 ),
               ),
               
               const SizedBox(height: 12),
               
               // Description
               Text(
                 profile.description,
                 maxLines: 4,
                 overflow: TextOverflow.ellipsis,
                 style: theme.textTheme.bodyMedium?.copyWith(
                   height: 1.5,
                   color: theme.textTheme.bodyMedium?.color?.withOpacity(0.9),
                 ),
               ),
            ],
          ),
        ),
      ),
    );
  }
}
