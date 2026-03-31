import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/founder_profile.dart';
import '../../../../core/theme/ffig_theme.dart';
import '../../chat/chat_screen.dart';
import '../../../../core/services/membership_service.dart';

class FounderSpotlightCard extends StatelessWidget {
  final FounderProfile profile;
  final Uint8List? localImageBytes;
  final VoidCallback? onTap;
  final bool isPreview;

  const FounderSpotlightCard({
    super.key,
    required this.profile,
    this.localImageBytes,
    this.onTap,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isPreview ? null : (onTap ?? () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              // Placeholder for FounderCard detail
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(profile.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(profile.bio),
                ],
              ),
            ),
          ),
        );
      }),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        height: 340,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full Bleed Image
              if (localImageBytes != null)
                Image.memory(
                  localImageBytes!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                )
              else
                Image.network(
                  profile.photoUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (c, e, s) => Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.person, color: Colors.white, size: 50),
                  ),
                ),

              // Gradient Overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.5, 1.0],
                  ),
                ),
              ),

              // Top Badge
              Positioned(
                top: 20,
                left: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.white.withOpacity(0.1),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFD4AF37), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "FOUNDER OF THE WEEK",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Details
              Positioned(
                bottom: 24,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.name.isEmpty ? "Name Placeholder" : profile.name,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.tier == 'PREMIUM' || profile.tier == 'STANDARD')
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Icon(
                              Icons.verified,
                              size: 20,
                              color: profile.tier == 'PREMIUM' 
                                  ? const Color(0xFFD4AF37) // Gold
                                  : const Color(0xFF007AFF), // Blue
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (profile.businessName.isEmpty ? "Business Name" : profile.businessName).toUpperCase(),
                      style: GoogleFonts.inter(
                        color: const Color(0xFFD4AF37),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Chat Button (Hide if isPreview)
                    if (!isPreview)
                      SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (profile.userId != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => ChatScreen(
                                  recipientId: profile.userId!,
                                  recipientName: profile.name,
                                ))
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Chat not available for this user"))
                              );
                            }
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
                          label: const Text("Chat", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
