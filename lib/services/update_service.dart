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
        final latestVersion = latest.tagName.replaceAll('v', '');
        
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
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();
      
      for (var i = 0; i < latestParts.length && i < currentParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (_) {
      return false;
    }
  }
}
