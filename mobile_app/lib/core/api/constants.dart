import 'package:flutter/foundation.dart';

String _ensureTrailingSlash(String url) {
  final normalized = url.trim();
  if (normalized.isEmpty) return normalized;
  return normalized.endsWith('/') ? normalized : '$normalized/';
}

String get baseUrl {
  const overrideUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (overrideUrl.isNotEmpty) {
    return _ensureTrailingSlash(overrideUrl);
  }

  if (kReleaseMode || kIsWeb) {
    return 'https://ffig-backend-ti5w.onrender.com/api/';
  }
  // Android emulator uses 10.0.2.2 to hit localhost
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000/api/';
  }
  // iOS/macOS debug defaults to hosted backend to avoid local-network
  // connection failures on physical devices.
  // To force local backend, run with:
  // --dart-define=API_BASE_URL=http://<your-ip>:8000/api/
  return 'https://ffig-backend-ti5w.onrender.com/api/';
}
