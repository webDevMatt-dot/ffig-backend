import 'package:flutter/foundation.dart';

String get baseUrl {
  if (kReleaseMode || kIsWeb) {
    return 'https://ffig-backend-ti5w.onrender.com/api/';
  }
  // Android emulator uses 10.0.2.2 to hit localhost
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000/api/';
  }
  // iOS simulator and local web debugging use 127.0.0.1 directly
  return 'http://127.0.0.1:8000/api/';
}
