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
        height: 250.0,
        autoPlay: true,
        enlargeCenterPage: true,
        aspectRatio: 16 / 9,
        autoPlayCurve: Curves.fastOutSlowIn,
        enableInfiniteScroll: true,
        autoPlayAnimationDuration: const Duration(milliseconds: 800),
        viewportFraction: 0.92,
      ),
      items: items.map((item) {
        return Builder(
          builder: (BuildContext context) {
            return GestureDetector(
              onTap: () {
                if (item.actionUrl != null) {
                  // Handle navigation
                  print("Navigate to ${item.actionUrl}");
                }
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                margin: const EdgeInsets.symmetric(horizontal: 5.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: NetworkImage(item.imageUrl),
                    fit: BoxFit.cover,
                  ),
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
