import 'package:flutter/material.dart';

class AdminDarkListItem extends StatelessWidget {
  const AdminDarkListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.fallbackIcon = Icons.image_outlined,
    this.statusChip,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final IconData fallbackIcon;
  final Widget? statusChip;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
            ? [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.04),
              ]
            : [
                Colors.black.withOpacity(0.03),
                Colors.black.withOpacity(0.01),
              ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: hasImage
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackPreview(),
                          )
                        : _fallbackPreview(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (statusChip != null) ...[
                            const SizedBox(width: 8),
                            statusChip!,
                          ],
                        ],
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ??
                    Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).disabledColor,
                      size: 28,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackPreview() {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        color: isDark ? const Color(0xFF1F2937) : Colors.grey[200],
        alignment: Alignment.center,
        child: Icon(
          fallbackIcon,
          color: isDark ? Colors.white70 : Colors.grey[500],
        ),
      );
    });
  }
}
