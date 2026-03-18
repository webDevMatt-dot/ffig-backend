import 'package:flutter/foundation.dart';

String get baseUrl {
  if (kReleaseMode || kIsWeb) {
    return 'https://ffig-backend-ti5w.onrender.com/api/';
  }
  // Android emulator uses 10.0.2.2 to hit localhost
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000/api/';
  }
  // iOS device, simulator, and local web debugging use the machine's local IP
  return 'http://192.168.0.3:8000/api/';
}
