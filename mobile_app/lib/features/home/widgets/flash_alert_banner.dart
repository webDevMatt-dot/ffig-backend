import 'package:flutter/material.dart';
import '../models/flash_alert.dart';
import 'package:url_launcher/url_launcher.dart';

class FlashAlertBanner extends StatelessWidget {
  final FlashAlert alert;

  const FlashAlertBanner({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    if (alert.isExpired) return const SizedBox.shrink();

    return Material(
      color: Colors.redAccent,
      child: InkWell(
        onTap: () {
          if (alert.actionUrl != null) {
            String url = alert.actionUrl!;
            // Fix legacy domain if present
            if (url.contains('ffig-mobile-app.onrender.com')) {
               url = url.replaceAll('ffig-mobile-app.onrender.com', 'femalefoundersinitiativeglobal.onrender.com');
            }
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.timer, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.type.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
