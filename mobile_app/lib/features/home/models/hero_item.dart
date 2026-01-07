class HeroItem {
  final String id;
  final String title;
  final String imageUrl;
  final String type; // e.g., "Announcement", "Sponsorship", "Update"
  final String? actionUrl;

  HeroItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.type,
    this.actionUrl,
  });

  factory HeroItem.fromJson(Map<String, dynamic> json) {
    return HeroItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      imageUrl: json['image_url'] ?? '',
      type: json['type'] ?? 'Update',
      actionUrl: json['action_url'],
    );
  }
}
