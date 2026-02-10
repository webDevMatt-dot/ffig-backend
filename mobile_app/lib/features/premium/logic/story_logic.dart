import 'package:flutter/foundation.dart';

class StoryLogic {
  
  /// Sorts stories based on:
  /// 1. Current User's Story (if exists) - handled by UI injection usually, but if in list, move to top.
  /// 2. Unseen Stories (prioritized)
  /// 3. Recent Timestamp
  static List<dynamic> sortStories(List<dynamic> stories, int? currentUserId) {
    if (stories.isEmpty) return [];

    // Create a mutable copy
    final List<dynamic> sorted = List.from(stories);

    sorted.sort((a, b) {
      // 1. Current user first
      int aId = a['user'] ?? -1; // Assuming 'user' is the ID field from Django
      int bId = b['user'] ?? -1;
      
      if (currentUserId != null) {
        if (aId == currentUserId) return -1;
        if (bId == currentUserId) return 1;
      }

      // 2. Unseen first (Mock logic for now, as backend doesn't send 'seen' yet)
      // For v1, we assume all fetched stories are "active". 
      // If we had a local 'seen' list, we would check it here.
      bool aSeen = false; 
      bool bSeen = false;
      if (aSeen != bSeen) {
        return aSeen ? 1 : -1; // Unseen comes first
      }

      // 3. Most recent first
      DateTime aTime = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
      DateTime bTime = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
      
      return bTime.compareTo(aTime);
    });

    return sorted;
  }
}
