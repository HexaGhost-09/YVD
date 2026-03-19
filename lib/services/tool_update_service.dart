import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../globals.dart';

enum ManagedBinary { ytDlp, aria2c }

class BinaryUpdateInfo {
  final ManagedBinary binary;
  final bool isSupported;
  final bool isInstalled;
  final bool updateAvailable;
  final String currentVersion;
  final String latestVersion;
  final String installedPath;
  final String releaseUrl;
  final String releaseNotes;

  const BinaryUpdateInfo({
    required this.binary,
    required this.isSupported,
    required this.isInstalled,
    required this.updateAvailable,
    required this.currentVersion,
    required this.latestVersion,
    required this.installedPath,
    required this.releaseUrl,
    required this.releaseNotes,
  });
}

class BinaryInstallResult {
  final String path;
  final String version;

  const BinaryInstallResult({required this.path, required this.version});
}

class ToolUpdateService {
  ToolUpdateService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _ytDlpLatestRelease = 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest';
  static const _ytDlpLatestWindows = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
  static const _ytDlpLatestLinux = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp';
  static const _ytDlpLatestMac = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos';
  
  // For Android, we use the architecture-specific binary if possible or the zipapp
  static const _ytDlpLatestAndroid = 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux_aarch64';
  
  static const _aria2cLatestRelease = 'https://api.github.com/repos/aria2/aria2/releases/latest';

  bool get _isSupportedPlatform => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid);

  Future<BinaryUpdateInfo> checkUpdate(ManagedBinary binary) async {
    if (!_isSupportedPlatform) {
      return BinaryUpdateInfo(
        binary: binary,
        isSupported: false,
        isInstalled: false,
        updateAvailable: false,
        currentVersion: 'Unsupported on this platform',
        latestVersion: 'Unavailable',
        installedPath: '',
        releaseUrl: '',
        releaseNotes: '',
      );
    }

    switch (binary) {
      case ManagedBinary.ytDlp:
        return _checkYtDlp();
      case ManagedBinary.aria2c:
        return _checkAria2c();
    }
  }

  Future<BinaryInstallResult> updateBinary(
    ManagedBinary binary, {
    void Function(double progress)? onProgress,
  }) async {
    if (!_isSupportedPlatform) {
      throw UnsupportedError('Binary updates are only supported on selected platforms.');
    }

    switch (binary) {
      case ManagedBinary.ytDlp:
        return _installYtDlp(onProgress: onProgress);
      case ManagedBinary.aria2c:
        return _installAria2cFromAssets();
    }
  }

  Future<BinaryUpdateInfo> _checkYtDlp() async {
    try {
      final latest = await _fetchReleaseJson(_ytDlpLatestRelease);
      final latestTag = _normalizeVersion(latest['tag_name']?.toString() ?? '');
      final latestNotes = latest['body']?.toString() ?? '';
      final currentPath = ytdlpPathNotifier.value.trim();
      final currentVersion = await _readExecutableVersion(currentPath, ['--version']);
      final installed = currentPath.isNotEmpty && File(currentPath).existsSync();
      final updateAvailable = !installed || (currentVersion.isNotEmpty && _isNewer(latestTag, currentVersion));

      return BinaryUpdateInfo(
        binary: ManagedBinary.ytDlp,
        isSupported: true,
        isInstalled: installed,
        updateAvailable: updateAvailable,
        currentVersion: installed ? currentVersion : 'Not installed',
        latestVersion: latestTag,
        installedPath: currentPath,
        releaseUrl: latest['html_url']?.toString() ?? '',
        releaseNotes: latestNotes,
      );
    } catch (e) {
      return _errorInfo(ManagedBinary.ytDlp, e.toString());
    }
  }

  Future<BinaryUpdateInfo> _checkAria2c() async {
    try {
      final currentPath = aria2cPathNotifier.value.trim();
      final installed = currentPath.isNotEmpty && File(currentPath).existsSync();
      final currentVersion = aria2cVersionNotifier.value.trim();

      return BinaryUpdateInfo(
        binary: ManagedBinary.aria2c,
        isSupported: true,
        isInstalled: installed,
        updateAvailable: false, // We update aria2c via app updates
        currentVersion: installed ? (currentVersion.isEmpty ? 'Installed' : currentVersion) : 'Not bundled',
        latestVersion: 'Bundled',
        installedPath: currentPath,
        releaseUrl: '',
        releaseNotes: 'aria2c is now bundled with the app for all platforms.',
      );
    } catch (e) {
      return _errorInfo(ManagedBinary.aria2c, e.toString());
    }
  }

  Future<BinaryInstallResult> _installYtDlp({void Function(double progress)? onProgress}) async {
    final latest = await _fetchReleaseJson(_ytDlpLatestRelease);
    final version = _normalizeVersion(latest['tag_name']?.toString() ?? '');
    final downloadUrl = _ytDlpDownloadUrl();
    final targetPath = await _resolveBinaryInstallPath('yt-dlp', downloadUrl.endsWith('.exe') ? 'yt-dlp.exe' : 'yt-dlp');
    await _downloadToFile(downloadUrl, targetPath, onProgress: onProgress);
    await _makeExecutableIfNeeded(targetPath);

    ytdlpPathNotifier.value = targetPath;
    ytdlpVersionNotifier.value = version;
    return BinaryInstallResult(path: targetPath, version: version);
  }

  Future<BinaryInstallResult> _installAria2cFromAssets() async {
    final version = '1.37.0'; // Hardcoded for bundled version
    final assetPath = Platform.isWindows ? 'assets/binaries/aria2c.exe' : 'assets/binaries/aria2c_android';
    final exeName = Platform.isWindows ? 'aria2c.exe' : 'aria2c';
    
    final targetPath = await _resolveBinaryInstallPath('aria2c', exeName);
    
    // Copy from assets to local filesystem
    final byteData = await rootBundle.load(assetPath);
    final file = File(targetPath);
    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    await _makeExecutableIfNeeded(targetPath);

    aria2cPathNotifier.value = targetPath;
    aria2cVersionNotifier.value = version;
    return BinaryInstallResult(path: targetPath, version: version);
  }



  Future<String> _installFromZip(String name, String url, String exeName, {void Function(double progress)? onProgress}) async {
    final supportDir = await getApplicationSupportDirectory();
    final installDir = Directory('${supportDir.path}${Platform.pathSeparator}binaries${Platform.pathSeparator}$name');
    if (await installDir.exists()) await installDir.delete(recursive: true);
    await installDir.create(recursive: true);

    final zipPath = '${installDir.path}${Platform.pathSeparator}$name.zip';
    await _downloadToFile(url, zipPath, onProgress: onProgress);

    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    extractArchiveToDisk(archive, installDir.path);

    File? foundExe;
    await for (final entity in installDir.list(recursive: true)) {
      if (entity is File && entity.path.toLowerCase().endsWith(exeName.toLowerCase())) {
        foundExe = entity;
        break;
      }
    }

    if (foundExe == null) throw StateError('Could not find $exeName in archive.');
    
    // Move to fixed location
    final finalPath = '${installDir.path}${Platform.pathSeparator}$exeName';
    await foundExe.copy(finalPath);
    
    // Cleanup
    try { await File(zipPath).delete(); } catch (_) {}
    
    return finalPath;
  }

  Future<Map<String, dynamic>> _fetchReleaseJson(String url) async {
    final response = await _dio.get<String>(url);
    if (response.statusCode != 200 || response.data == null) throw StateError('Failed to fetch release metadata.');
    return jsonDecode(response.data!) as Map<String, dynamic>;
  }

  String _ytDlpDownloadUrl() {
    if (Platform.isWindows) return _ytDlpLatestWindows;
    if (Platform.isAndroid) return _ytDlpLatestAndroid;
    if (Platform.isLinux) return _ytDlpLatestLinux;
    return _ytDlpLatestMac;
  }

  Future<String> _resolveBinaryInstallPath(String folder, String fileName) async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}${Platform.pathSeparator}binaries${Platform.pathSeparator}$folder');
    await dir.create(recursive: true);
    return '${dir.path}${Platform.pathSeparator}$fileName';
  }

  Map<String, dynamic> _selectAsset(List<dynamic> assets, bool Function(String name) predicate) {
    for (final asset in assets.whereType<Map<String, dynamic>>()) {
      if (predicate(asset['name']?.toString().toLowerCase() ?? '')) return asset;
    }
    throw StateError('No compatible asset found.');
  }

  Future<void> _downloadToFile(String url, String path, {void Function(double progress)? onProgress}) async {
    final response = await _dio.get<ResponseBody>(url, options: Options(responseType: ResponseType.stream));
    final length = int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '') ?? -1;
    final sink = File(path).openWrite();
    int received = 0;
    try {
      await for (final chunk in response.data!.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (length > 0) onProgress?.call(received / length);
      }
    } finally {
      await sink.flush(); await sink.close();
    }
  }

  Future<String> _readExecutableVersion(String path, List<String> args) async {
    if (path.isEmpty || !File(path).existsSync()) return '';
    try {
      final result = await Process.run(path, args);
      return result.stdout.toString().trim().split('\n').first.trim();
    } catch (_) { return ''; }
  }

  Future<void> _makeExecutableIfNeeded(String path) async {
    if (!Platform.isWindows) try { await Process.run('chmod', ['755', path]); } catch (_) {}
  }

  BinaryUpdateInfo _errorInfo(ManagedBinary binary, String error) => BinaryUpdateInfo(
    binary: binary, isSupported: true, isInstalled: false, updateAvailable: false,
    currentVersion: 'Error', latestVersion: 'Unknown', installedPath: '',
    releaseUrl: '', releaseNotes: error,
  );

  String _normalizeVersion(String version) => version.trim().startsWith('v') ? version.trim().substring(1) : version.trim();

  bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
    for (var i = 0; i < l.length && i < c.length; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return l.length > c.length;
  }
}
