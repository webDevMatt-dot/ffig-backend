import 'package:flutter/foundation.dart';

String get baseUrl {
  if (kReleaseMode || kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
    return 'https://ffig-backend-ti5w.onrender.com/api/';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000/api/';
  }
  return 'http://localhost:8000/api/';
}
