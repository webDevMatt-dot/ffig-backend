import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class NewsTicker extends StatelessWidget {
  final List<String> newsItems;

  const NewsTicker({super.key, required this.newsItems});

  @override
  Widget build(BuildContext context) {
    if (newsItems.isEmpty) return const SizedBox.shrink();

    final String fullText = newsItems.join("   •   ");

    return Container(
      height: 40,
      color: Theme.of(context).colorScheme.surfaceVariant, // Adaptive background
      child: Marquee(
        text: fullText,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
        scrollAxis: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.center,
        blankSpace: 20.0,
        velocity: 50.0,
        pauseAfterRound: const Duration(seconds: 1),
        startPadding: 10.0,
        accelerationDuration: const Duration(seconds: 1),
        accelerationCurve: Curves.linear,
        decelerationDuration: const Duration(milliseconds: 500),
        decelerationCurve: Curves.easeOut,
      ),
    );
  }
}
