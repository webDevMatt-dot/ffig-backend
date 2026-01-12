import 'package:flutter/material.dart';
import '../core/theme/ffig_theme.dart';

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

  String _getInitials() {
    String first = firstName?.trim() ?? '';
    String last = lastName?.trim() ?? '';
    
    // 1. Try First + Last
    if (first.isNotEmpty && last.isNotEmpty) {
      return "${first[0]}${last[0]}".toUpperCase();
    }
    
    // 2. Try just First
    if (first.isNotEmpty) {
      return first[0].toUpperCase();
    }

    // 3. Fallback to Username
    if (username != null && username!.isNotEmpty) {
      return username![0].toUpperCase();
    }

    return "?";
  }

  @override
  Widget build(BuildContext context) {
    // Hack: Ignore the Backend's default "Yellow" UI Avatar so we can use our own Themed one.
    bool useUrl = imageUrl != null && imageUrl!.isNotEmpty && !imageUrl!.contains("ui-avatars.com");

    final bgColor = backgroundColor ?? FfigTheme.primaryBrown.withOpacity(0.1);
    final txtColor = textColor ?? FfigTheme.primaryBrown;

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      // Use ClipOval child instead of backgroundImage to safely handle 404s on Web
      child: ClipOval(
        child: SizedBox.fromSize(
          size: Size.fromRadius(radius),
          child: useUrl 
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                   return _buildInitials(bgColor, txtColor);
                },
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
