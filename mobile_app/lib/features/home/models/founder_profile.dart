class FounderProfile {
  final String id;
  final String name;
  final String photoUrl;
  final String bio;
  final String country;
  final String businessName;
  final bool isPremium;

  FounderProfile({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.bio,
    required this.country,
    required this.businessName,
    this.isPremium = false,
  });

  factory FounderProfile.fromJson(Map<String, dynamic> json) {
    return FounderProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      photoUrl: json['photo_url'] ?? '',
      bio: json['bio'] ?? '',
      country: json['country'] ?? '',
      businessName: json['business_name'] ?? '',
      isPremium: json['is_premium'] ?? false,
    );
  }
}
