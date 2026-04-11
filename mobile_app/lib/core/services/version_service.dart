import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../api/django_api_client.dart';

class VersionService {
  final _apiClient = DjangoApiClient();

  Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final raw = await _apiClient.get(
        'home/version/',
        requiresAuth: false,
        retryEnabled: true,
      );
      if (raw is List) {
        final List<dynamic> data = raw;
        
        String platformName = 'ANDROID';
        if (kIsWeb) {
             platformName = 'WEB';
        } else if (Platform.isIOS) {
             platformName = 'IOS';
        }
        
        final versionData = data.firstWhere(
          (v) => v['platform'] == platformName,
          orElse: () => null,
        );
            
        if (versionData != null) {
          final PackageInfo packageInfo = await PackageInfo.fromPlatform();
          final currentVersion = packageInfo.version;
          final latestVersion = versionData['latest_version'];
          
          if (_isUpdateAvailable(currentVersion, latestVersion)) {
             return {
               'updateAvailable': true,
               'latestVersion': latestVersion,
               'url': versionData['update_url'],
               'required': versionData['required'] ?? false
             };
          }
        }
      }
    } catch (e) {
      debugPrint("Version check error: $e");
    }
    return null;
  }

  bool _isUpdateAvailable(String current, String latest) {
    if (current == latest) return false;
    
    List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    for (int i = 0; i < l.length; i++) {
        if (i >= c.length) return true; 
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
    }
    return false; 
  }
}
