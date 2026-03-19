import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class GitHubRelease {
  final String tagName;
  final String htmlUrl;
  final String body;

  GitHubRelease({required this.tagName, required this.htmlUrl, required this.body});

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    return GitHubRelease(
      tagName: json['tag_name'] ?? '',
      htmlUrl: json['html_url'] ?? '',
      body: json['body'] ?? '',
    );
  }
}

class UpdateService {
  final Dio _dio = Dio();
  static const String repoUrl = 'https://api.github.com/repos/HexaGhost-09/YVD/releases/latest';

  Future<GitHubRelease?> checkForUpdate() async {
    try {
      final response = await _dio.get(repoUrl);
      if (response.statusCode == 200) {
        final latest = GitHubRelease.fromJson(response.data);
        final currentInfo = await PackageInfo.fromPlatform();
        
        final currentVersion = currentInfo.version;
        // Strip 'v' and any other prefixes
        final latestTag = latest.tagName.toLowerCase();
        final latestVersion = latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;
        
        print('Checking update: Current Version $currentVersion, Latest available: $latestVersion');
        
        if (_isNewer(latestVersion, currentVersion)) {
          return latest;
        }
      }
    } catch (e) {
      print('Update check failed: $e');
    }
    return null;
  }

  bool _isNewer(String latest, String current) {
    try {
      final latestParts = latest.split('.').map((e) => int.parse(e.replaceAll(RegExp(r'\D'), ''))).toList();
      final currentParts = current.split('.').map((e) => int.parse(e.replaceAll(RegExp(r'\D'), ''))).toList();
      
      int length = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
      
      for (var i = 0; i < length; i++) {
        int latestVal = i < latestParts.length ? latestParts[i] : 0;
        int currentVal = i < currentParts.length ? currentParts[i] : 0;
        
        if (latestVal > currentVal) return true;
        if (latestVal < currentVal) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
