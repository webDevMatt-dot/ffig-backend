import 'package:flutter/foundation.dart';

const String baseUrl = (kReleaseMode || kIsWeb)
    ? 'https://ffig-backend-ti5w.onrender.com/api/' 
    : 'http://localhost:8000/api/';
