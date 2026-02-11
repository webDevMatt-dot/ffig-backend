import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // For ImageFilter
import '../../../core/theme/ffig_theme.dart';

/// A reusable tile component for the Bento Grid layout.
/// - Supports custom background colors or Glassmorphism.
/// - Configurable title, subtitle, icon, and tap action.
class BentoTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? child;
  final Widget? icon;
  final VoidCallback onTap;
  final bool isGlass;
  final Color? color;
  final double height;
  final double? width;

  const BentoTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.child,
    this.icon,
    this.isGlass = false,
    this.color,
    this.height = 180,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final isDark = theme.brightness == Brightness.dark;

    Widget content = Container(
      width: width ?? double.infinity,
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color ?? theme.cardTheme.color,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        gradient: isGlass ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ? [
            const Color(0xFF2C2C2C).withOpacity(0.4),
            const Color(0xFF0D1117).withOpacity(0.6),
          ] : [
            Colors.white.withOpacity(0.6),
            Colors.white.withOpacity(0.4),
          ],
        ) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : FfigTheme.primaryBrown.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: icon,
                ),
              if (icon != null) const Spacer(),
              Icon(Icons.arrow_outward, color: isDark ? Colors.grey : Colors.grey[400], size: 16),
            ],
          ),
          if (icon != null) const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.grey : Colors.black54, // Darker text for light mode
                fontWeight: isDark ? FontWeight.normal : FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (child != null) ...[
             const Spacer(),
             child!,
          ]
        ],
      ),
    );

    if (isGlass) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: content,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: content,
    );
  }
}
