class FlashAlert {
  final String id;
  final String title;
  final String message;
  final DateTime expiryTime;
  final String? actionUrl;
  final String type; // "Happening Soon", "Tickets Closing"

  FlashAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.expiryTime,
    this.actionUrl,
    required this.type,
  });

  bool get isExpired => DateTime.now().isAfter(expiryTime);

  factory FlashAlert.fromJson(Map<String, dynamic> json) {
    return FlashAlert(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      expiryTime: DateTime.parse(json['expiry_time']),
      actionUrl: json['action_url'],
      type: json['type'] ?? 'Alert',
    );
  }
}
