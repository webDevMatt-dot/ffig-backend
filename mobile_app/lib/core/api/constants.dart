import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

const String baseUrl = (kReleaseMode || kIsWeb)
    ? 'https://ffig-backend-ti5w.onrender.com/api/' 
    : (Platform.isAndroid ? 'http://10.0.2.2:8000/api/' : 'http://localhost:8000/api/');
