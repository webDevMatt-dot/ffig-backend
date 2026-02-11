import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/ffig_theme.dart';

/// A specialized animated navigation bar with a glassmorphism effect.
///
/// **Features:**
/// - Floating design with rounded corners and shadow.
/// - Frosted glass effect using `BackdropFilter` and `ImageFilter.blur`.
/// - Animated selection state (pill shape background).
/// - Supports customizable icons and labels.
class GlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final List<GlassNavItem> items;

  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 32),
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22).withOpacity(0.8), // Dark Obsidian with opacity
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: items.map((item) {
              final index = items.indexOf(item);
              final isSelected = selectedIndex == index;
              
              return GestureDetector(
                onTap: () => onItemSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: isSelected ? BoxDecoration(
                    color: FfigTheme.primaryBrown.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(24),
                  ) : null,
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected ? FfigTheme.primaryBrown : Colors.grey,
                        size: 24,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: FfigTheme.primaryBrown,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  GlassNavItem({required this.icon, required this.activeIcon, required this.label});
}
