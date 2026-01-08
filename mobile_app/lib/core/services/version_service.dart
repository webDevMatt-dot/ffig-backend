import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../api/constants.dart';

class VersionService {
  Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      // Endpoint: constants.baseUrl usually is "https://.../api/"
      // We need "https://.../api/home/version/"
      final uri = Uri.parse('${baseUrl}home/version/');
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        
        String platformName = 'ANDROID';
        if (Platform.isIOS) platformName = 'IOS';
        
        final versionData = data.firstWhere(
            (v) => v['platform'] == platformName, orElse: () => null);
            
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
      print("Version check error: $e");
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
