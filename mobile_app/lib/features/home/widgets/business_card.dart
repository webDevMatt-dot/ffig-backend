import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // For ImageFilter
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../shared_widgets/user_avatar.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../models/business_profile.dart';
import '../business_detail_screen.dart';

/// Displays a premium, featured card for the "Business of the Month".
/// - Matches the "Founder of the Week" aesthetic.
/// - Uses a background image with gradient overlay.
/// - Glassmorphic badge and navigation to Detail Screen.
class BusinessCard extends StatelessWidget {
  final BusinessProfile profile;

  const BusinessCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 1.6, // Featured look
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Background Image
                if (profile.imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: profile.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: theme.cardColor),
                    errorWidget: (context, url, error) => Container(
                      color: theme.cardColor,
                      child: const Icon(Icons.business, size: 48, color: Colors.grey),
                    ),
                  )
                else
                  Container(color: theme.cardColor),

                // 2. Gradient Overlay for Text Readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),

                // 3. Top-Left Badge: Spotlight
                Positioned(
                  top: 16,
                  left: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: Colors.white.withOpacity(0.15),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Color(0xFFD4AF37), size: 14), // Gold star
                            const SizedBox(width: 8),
                            Text(
                              "BUSINESS OF THE MONTH",
                              style: GoogleFonts.inter(
                                color: Colors.white, 
                                fontSize: 10, 
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Content Content
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (context) => BusinessDetailScreen(profile: profile),
                         ),
                       );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile.name,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (profile.isPremium) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.verified, color: Colors.amber, size: 20),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.location.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: const Color(0xFFD4AF37), // Gold
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Text(
                                "See Details",
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_outward, 
                                size: 14, 
                                color: Colors.white.withOpacity(0.8)
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
