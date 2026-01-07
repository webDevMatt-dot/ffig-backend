import 'package:flutter/foundation.dart';

const String baseUrl = (kReleaseMode || kIsWeb)
    ? 'https://ffig-api.onrender.com/api/' 
    : 'http://localhost:8000/api/';
