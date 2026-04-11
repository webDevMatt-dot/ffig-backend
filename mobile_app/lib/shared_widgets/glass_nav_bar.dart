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
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final horizontalMargin = screenWidth < 370 ? 12.0 : 24.0;
        final availableBarWidth = screenWidth - (horizontalMargin * 2);
        final slotWidth = items.isEmpty ? availableBarWidth : (availableBarWidth / items.length);
        final showSelectedLabel = slotWidth >= 84;

        return Container(
          margin: EdgeInsets.only(left: horizontalMargin, right: horizontalMargin, bottom: 32),
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
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = selectedIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onItemSelected(index),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            horizontal: (isSelected && showSelectedLabel) ? 10 : 8,
                            vertical: 12,
                          ),
                          decoration: isSelected
                              ? BoxDecoration(
                                  color: FfigTheme.primaryBrown.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(24),
                                )
                              : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Badge(
                                isLabelVisible: item.badgeCount > 0,
                                label: Text('${item.badgeCount}'),
                                child: Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  color: isSelected ? FfigTheme.primaryBrown : Colors.grey,
                                  size: 24,
                                ),
                              ),
                              if (isSelected && showSelectedLabel) ...[
                                const SizedBox(width: 6),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FfigTheme.primaryBrown,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;

  GlassNavItem({
    required this.icon, 
    required this.activeIcon, 
    required this.label,
    this.badgeCount = 0,
  });
}
