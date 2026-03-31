import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/ffig_theme.dart';
import '../../../../shared_widgets/user_avatar.dart';
import '../models/founder_profile.dart';

/// Displays a detailed card for the "Founder of the Week".
/// - Shows Avatar, Name, Business, Country, and Bio.
/// - Used in the Bento Grid and modal dialogs.
class FounderCard extends StatefulWidget {
  final FounderProfile profile;

  const FounderCard({super.key, required this.profile});

  @override
  State<FounderCard> createState() => _FounderCardState();
}

class _FounderCardState extends State<FounderCard> {
  Color _badgeTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _updateBadgeTextColor();
  }

  @override
  void didUpdateWidget(covariant FounderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.photoUrl != widget.profile.photoUrl) {
      _updateBadgeTextColor();
    }
  }

  Future<void> _updateBadgeTextColor() async {
    final photoUrl = widget.profile.photoUrl;
    if (photoUrl.isEmpty) {
      if (mounted) {
        setState(() => _badgeTextColor = Colors.black);
      }
      return;
    }

    final isLightImage = await _isLightImage(NetworkImage(photoUrl));
    if (!mounted) {
      return;
    }

    setState(() {
      _badgeTextColor = isLightImage ? Colors.black : Colors.white;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = theme.cardColor;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final shadowColor = isDark ? Colors.transparent : Colors.black.withOpacity(0.05);
    final badgeBg = isDark ? Colors.black.withOpacity(0.25) : Colors.white.withOpacity(0.35);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Container(
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        imageUrl: widget.profile.photoUrl,
                        firstName: widget.profile.name.split(' ').first,
                        lastName: widget.profile.name.split(' ').length > 1 ? widget.profile.name.split(' ').last : '',
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
                                  widget.profile.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              if (widget.profile.isPremium) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Colors.amber, size: 16),
                              ] else ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: FfigTheme.primaryBrown, size: 16),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.profile.businessName,
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
                                widget.profile.country,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, color: _badgeTextColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'FOUNDER OF THE WEEK',
                        style: TextStyle(
                          color: _badgeTextColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      widget.profile.bio,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.9),
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

Future<bool> _isLightImage(ImageProvider imageProvider) async {
  final imageStream = imageProvider.resolve(const ImageConfiguration());
  final completer = Completer<ImageInfo>();

  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo image, bool synchronousCall) {
      completer.complete(image);
      imageStream.removeListener(listener);
    },
    onError: (dynamic error, StackTrace? stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      imageStream.removeListener(listener);
    },
  );

  imageStream.addListener(listener);

  try {
    final imageInfo = await completer.future;
    final uiImage = imageInfo.image;
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return false;
    }

    final bytes = byteData.buffer.asUint8List();
    final pixelCount = uiImage.width * uiImage.height;
    if (pixelCount == 0) {
      return false;
    }

    final stride = (pixelCount / 1000).ceil().clamp(1, pixelCount);
    double luminanceSum = 0;
    int sampled = 0;

    for (int pixelIndex = 0; pixelIndex < pixelCount; pixelIndex += stride) {
      final base = pixelIndex * 4;
      final r = bytes[base] / 255.0;
      final g = bytes[base + 1] / 255.0;
      final b = bytes[base + 2] / 255.0;
      luminanceSum += (0.2126 * r) + (0.7152 * g) + (0.0722 * b);
      sampled++;
    }

    final averageLuminance = sampled == 0 ? 0.0 : luminanceSum / sampled;
    return averageLuminance > 0.6;
  } catch (_) {
    return false;
  }
}
