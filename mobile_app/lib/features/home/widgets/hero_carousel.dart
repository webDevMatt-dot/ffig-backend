import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hero_item.dart';
import 'hero_banner.dart';

/// Displays a rotating carousel of highlight items at the top of the Home Dashboard.
/// - Supports tap actions (external links).
/// - Fallback images and gradients for text readability.
class HeroCarousel extends StatelessWidget {
  final List<HeroItem> items;

  const HeroCarousel({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return CarouselSlider(
      options: CarouselOptions(
        height: 160.0, 
        autoPlay: true,
        enlargeCenterPage: true,
        aspectRatio: 2.2,
        autoPlayCurve: Curves.fastOutSlowIn,
        enableInfiniteScroll: true,
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        viewportFraction: 0.9,
      ),
      items: items.map((HeroItem item) {
        return HeroBanner(
          item: item,
          onTap: () {
            if (item.actionUrl != null && item.actionUrl!.isNotEmpty) {
              String url = item.actionUrl!;
              // Fix legacy domain if present
              if (url.contains('ffig-mobile-app.onrender.com') || url.contains('femalefoundersinitiativeglobal.onrender.com')) {
                 url = url.replaceAll('ffig-mobile-app.onrender.com', 'ffig-backend-ti5w.onrender.com')
                          .replaceAll('femalefoundersinitiativeglobal.onrender.com', 'ffig-backend-ti5w.onrender.com');
              }
              
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }
          },
        );
      }).toList(),
    );
  }
}
