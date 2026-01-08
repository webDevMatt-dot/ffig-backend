import 'package:flutter/material.dart';
import '../../../../shared_widgets/user_avatar.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../models/founder_profile.dart';

class FounderCard extends StatelessWidget {
  final FounderProfile profile;

  const FounderCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Define colors relative to Theme
    final cardColor = theme.cardColor;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final shadowColor = isDark ? Colors.transparent : Colors.black.withOpacity(0.05);
    final badgeBg = isDark ? FfigTheme.primaryBrown.withOpacity(0.2) : FfigTheme.primaryBrown.withOpacity(0.1);
    final badgeText = FfigTheme.primaryBrown;

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
           // Navigation placeholder
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               // Header: Avatar + Info
               Row(
                 children: [
                   Container(
                     padding: const EdgeInsets.all(2),
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       border: Border.all(color: FfigTheme.primaryBrown, width: 2),
                     ),
                     child: UserAvatar(
                       radius: 28,
                       imageUrl: profile.photoUrl,
                       firstName: profile.name.split(' ').first,
                       lastName: profile.name.split(' ').length > 1 ? profile.name.split(' ').last : '',
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
                                Icon(Icons.verified, color: FfigTheme.primaryBrown, size: 16),
                             ]
                           ],
                         ),
                         const SizedBox(height: 4),
                         Text(
                           profile.businessName,
                           style: theme.textTheme.bodyMedium?.copyWith(
                             color: FfigTheme.primaryBrown,
                             fontWeight: FontWeight.w600,
                           ),
                         ),
                         const SizedBox(height: 4),
                         Row(
                           children: [
                             Icon(Icons.location_on_outlined, size: 14, color: theme.hintColor),
                             const SizedBox(width: 4),
                             Text(
                               profile.country, 
                               style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                             ),
                           ],
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
                     Icon(Icons.star_rounded, color: badgeText, size: 16),
                     const SizedBox(width: 6),
                     Text(
                       "FOUNDER OF THE WEEK",
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
               
               // Bio
               Text(
                 profile.bio,
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
