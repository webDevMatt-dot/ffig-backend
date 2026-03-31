class FounderProfile {
  final String id;
  final String name;
  final String photoUrl;
  final String bio;
  final String country;
  final String businessName;
  final bool isPremium;
  final String tier;
  final dynamic userId;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  FounderProfile({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.bio,
    required this.country,
    required this.businessName,
    this.isPremium = false,
    this.tier = 'FREE',
    this.userId,
    this.isActive = true,
    this.expiresAt,
    this.createdAt,
  });

  factory FounderProfile.fromJson(Map<String, dynamic> json) {
    return FounderProfile(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      photoUrl: json['photo_url'] ?? '',
      bio: json['bio'] ?? '',
      country: json['country'] ?? '',
      businessName: json['business_name'] ?? '',
      isPremium: json['is_premium'] ?? false,
      tier: json['tier'] ?? 'FREE',
      userId: json['user_id'] ?? json['user'],
      isActive: json['is_active'] ?? true,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }
}
