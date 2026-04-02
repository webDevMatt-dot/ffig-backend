import 'package:flutter/foundation.dart';

String get baseUrl {
  if (kReleaseMode || kIsWeb) {
    return 'https://ffig-backend-ti5w.onrender.com/api/';
  }
  // Android emulator uses 10.0.2.2 to hit localhost
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000/api/';
  }
  // Updated to 'localhost' for Simulator reliability. 
  // For physical devices, use the machine's IP (e.g. 192.168.0.6)
  return 'http://localhost:8000/api/'; 
}
