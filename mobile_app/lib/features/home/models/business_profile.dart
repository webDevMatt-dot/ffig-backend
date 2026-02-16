class BusinessProfile {
  final String id;
  final String name;
  final String imageUrl; // Can be logo or featured image
  final String description;
  final String location;
  final String website;
  final bool isPremium;

  BusinessProfile({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.description,
    required this.location,
    required this.website,
    this.isPremium = false,
  });

  factory BusinessProfile.fromJson(Map<String, dynamic> json) {
    return BusinessProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image_url'] ?? json['photo_url'] ?? '', // Handle potential backend naming variations
      description: json['description'] ?? json['bio'] ?? '',
      location: json['location'] ?? json['country'] ?? '',
      website: json['website'] ?? '',
      isPremium: json['is_premium'] ?? false,
    );
  }
}
