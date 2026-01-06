import 'package:flutter/material.dart';

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
    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: backgroundColor ?? Colors.grey.shade200,
        child: (imageUrl != null && imageUrl!.isNotEmpty) 
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildInitials();
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildInitials(); // Show initials while loading or spinner? Initials is smoother.
                },
              )
            : _buildInitials(),
      ),
    );
  }

  Widget _buildInitials() {
    return Container(
      color: backgroundColor ?? Colors.grey.shade200,
      alignment: Alignment.center,
      child: Text(
        _getInitials(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8, 
          color: textColor ?? Colors.grey.shade600,
        ),
      ),
    );
  }
}
