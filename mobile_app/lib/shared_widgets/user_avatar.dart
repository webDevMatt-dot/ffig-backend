import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/theme/ffig_theme.dart';

/// A standardized User Avatar widget used throughout the app.
///
/// **Functionality:**
/// - Displays a network image if a valid URL is provided.
/// - Automatically handles 404s or invalid URLs by falling back to initials.
/// - Generates initials from First/Last name or Username.
/// - Uses CachedNetworkImage to prevent flickering on rebuilds.
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? firstName;
  final String? lastName;
  final String? username;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.firstName,
    this.lastName,
    this.username,
    this.radius = 24,
    this.backgroundColor,
    this.textColor,
  });

  /// Extracts initials from the provided name fields.
  String _getInitials() {
    String first = firstName?.trim() ?? '';
    String last = lastName?.trim() ?? '';
    
    if (first.isNotEmpty && last.isNotEmpty) {
      return "${first[0]}${last[0]}".toUpperCase();
    }
    if (first.isNotEmpty) {
      return first[0].toUpperCase();
    }
    if (username != null && username!.isNotEmpty) {
      return username![0].toUpperCase();
    }
    return "?";
  }

  @override
  Widget build(BuildContext context) {
    bool useUrl = imageUrl != null && 
                  imageUrl!.isNotEmpty && 
                  imageUrl != "null" &&
                  !imageUrl!.contains("ui-avatars.com");

    final bgColor = backgroundColor ?? FfigTheme.primaryBrown.withOpacity(0.1);
    final txtColor = textColor ?? FfigTheme.primaryBrown;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: ClipOval(
        child: SizedBox.fromSize(
          size: Size.fromRadius(radius),
          child: useUrl 
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildInitials(bgColor, txtColor),
                errorWidget: (context, url, error) => _buildInitials(bgColor, txtColor),
                // Ensure the same image isn't re-fetched if the URL is the same
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
              )
            : _buildInitials(bgColor, txtColor),
        ),
      ),
    );
  }

  Widget _buildInitials(Color bg, Color txt) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _getInitials(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8, 
          color: txt,
        ),
      ),
    );
  }
}

