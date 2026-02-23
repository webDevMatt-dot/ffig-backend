import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../shared_widgets/user_avatar.dart';
import '../../../core/theme/ffig_theme.dart';

/// A widget that displays a circular user avatar with a gradient border to indicate a story.
///
/// This widget is used in the `StoriesBar` to represent a user's story.
/// It visualizes different states:
/// - **Add Story:** Shows a plus icon if `isAdd` is true, allowing the current user to post.
/// - **Unseen Story:** Shows a Gradient border (Gold to Bronze) if the story hasn't been watched.
/// - **Seen Story:** Shows a Grey border if the story has already been viewed.
class StoryBubble extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isAdd;
  final bool isSeen;
  final VoidCallback onTap;

  const StoryBubble({
    super.key,
    required this.name,
    this.imageUrl,
    this.isAdd = false,
    this.isSeen = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                // The main circular container with border logic
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // GRADIENT LOGIC:
                    // - No gradient for "Add" button
                    // - No gradient for "Seen" stories
                    // - Gold/Bronze gradient for "Unseen" stories
                    gradient: isAdd
                        ? null
                        : (isSeen
                            ? null 
                            : const LinearGradient(
                                colors: [Color(0xFFD4AF37), Color(0xFF8B4513)], // Gold to Bronze
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )),
                    // BORDER LOGIC:
                    // - White/Transparent border for "Add"
                    // - Grey border for "Seen"
                    border: Border.all(
                      color: isAdd 
                          ? Colors.white.withOpacity(0.15) 
                          : (isSeen ? Colors.grey.shade700 : const Color(0xFFD4AF37)),
                      width: isSeen ? 1.5 : 2.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFF0D1117),
                    child: isAdd
                        ? Icon(Icons.add, size: 28, color: FfigTheme.primaryBrown)
                        : UserAvatar(
                            imageUrl: imageUrl,
                            radius: 30,
                            username: name,
                          ),
                  ),
                ),
                // Small Plus Badge for the "Add Story" bubble
                if (isAdd)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: FfigTheme.primaryBrown,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.black),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // User Name below the bubble
            SizedBox(
              width: 72,
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isAdd ? Colors.grey[400] : (isSeen ? Colors.grey[500] : Colors.white),
                  fontSize: 11,
                  fontWeight: isSeen ? FontWeight.w400 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A placeholder widget that displays a shimmering effect while stories are loading.
///
/// This mimics the shape and size of a `StoryBubble` to provide a smooth loading experience.
class ShimmerStoryBubble extends StatelessWidget {
  const ShimmerStoryBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circle Shimmer
          Shimmer.fromColors(
            baseColor: Colors.grey.shade800,
            highlightColor: Colors.grey.shade700,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Text Line Shimmer
          Shimmer.fromColors(
            baseColor: Colors.grey.shade800,
            highlightColor: Colors.grey.shade700,
            child: Container(
              width: 50,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
