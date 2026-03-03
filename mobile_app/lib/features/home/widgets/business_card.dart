import 'dart:async';
import 'dart:ui'; // For ImageFilter
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../business_detail_screen.dart';
import '../models/business_profile.dart';

/// Displays a premium, featured card for the "Business of the Month".
/// - Matches the "Founder of the Week" aesthetic.
/// - Uses a background image with gradient overlay.
/// - Glassmorphic badge and navigation to Detail Screen.
class BusinessCard extends StatefulWidget {
  final BusinessProfile profile;

  const BusinessCard({super.key, required this.profile});

  @override
  State<BusinessCard> createState() => _BusinessCardState();
}

class _BusinessCardState extends State<BusinessCard> {
  Color _badgeTextColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _updateBadgeTextColor();
  }

  @override
  void didUpdateWidget(covariant BusinessCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.imageUrl != widget.profile.imageUrl) {
      _updateBadgeTextColor();
    }
  }

  Future<void> _updateBadgeTextColor() async {
    final imageUrl = widget.profile.imageUrl;
    if (imageUrl.isEmpty) {
      if (mounted) {
        setState(() => _badgeTextColor = Colors.black);
      }
      return;
    }

    final isLightImage = await _isLightImage(CachedNetworkImageProvider(imageUrl));
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

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: AspectRatio(
          aspectRatio: 1.6, // Featured look
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.profile.imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: widget.profile.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: theme.cardColor),
                  errorWidget: (context, url, error) => Container(
                    color: theme.cardColor,
                    child: const Icon(Icons.business, size: 48, color: Colors.grey),
                  ),
                )
              else
                Container(color: theme.cardColor),
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
                          Icon(Icons.star, color: _badgeTextColor, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            'BUSINESS OF THE MONTH',
                            style: GoogleFonts.inter(
                              color: _badgeTextColor,
                              fontSize: 10,
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
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessDetailScreen(profile: widget.profile),
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
                                widget.profile.name,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.profile.isPremium) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.verified, color: Colors.amber, size: 20),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.profile.location.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: const Color(0xFFD4AF37),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'See Details',
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
                              color: Colors.white.withOpacity(0.8),
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
