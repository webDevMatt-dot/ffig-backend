import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import '../models/hero_item.dart';

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
      items: items.map((item) {
        return Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                if (item.actionUrl != null && item.actionUrl!.isNotEmpty) {
                  String url = item.actionUrl!;
                   // Fix legacy domain if present
                  if (url.contains('ffig-mobile-app.onrender.com')) {
                     url = url.replaceAll('ffig-mobile-app.onrender.com', 'femalefoundersinitiativeglobal.onrender.com');
                  }
                  // Need to import url_launcher at top of file
                  // But wait, I need to check imports first.
                  // Assuming I can add import or it exists? It DOES NOT exist in HeroCarousel.dart.
                  // I will need to add import too. 
                  // I'll do that in a separate step or try to add it now?
                  // Providing just the block is risky if import missing.
                  // I'll assume import needs adding.
                }
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: item.imageUrl.isNotEmpty 
                        ? NetworkImage(item.imageUrl) as ImageProvider
                        : const AssetImage('assets/images/placeholder.png'), // Fallback
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {
                        // Handle error silently or show placeholder
                        // Since DecorationImage doesn't support onError easily like Image.network, 
                        // we might need a different approach or just accept it.
                        // Ideally use CachedNetworkImage with errorWidget.
                    }
                  ),
                  color: Colors.grey[300], // Background if image fails loading
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.type.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}
