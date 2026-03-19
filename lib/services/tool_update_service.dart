import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../globals.dart';

enum ManagedBinary { ytDlp, ffmpeg }

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

  static const _ytDlpLatestRelease =
      'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest';
  static const _ytDlpLatestWindows =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
  static const _ytDlpLatestLinux =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp';
  static const _ytDlpLatestMac =
      'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos';
  static const _ffmpegLatestRelease =
      'https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest';

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  bool get _supportsFfmpegUpdate => !kIsWeb && Platform.isWindows;

  Future<BinaryUpdateInfo> checkUpdate(ManagedBinary binary) async {
    if (!_isDesktop) {
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
      case ManagedBinary.ffmpeg:
        return _checkFfmpeg();
    }
  }

  Future<BinaryInstallResult> updateBinary(
    ManagedBinary binary, {
    void Function(double progress)? onProgress,
  }) async {
    if (!_isDesktop) {
      throw UnsupportedError('Binary updates are only supported on desktop.');
    }

    switch (binary) {
      case ManagedBinary.ytDlp:
        return _installYtDlp(onProgress: onProgress);
      case ManagedBinary.ffmpeg:
        return _installFfmpegWindows(onProgress: onProgress);
    }
  }

  Future<BinaryUpdateInfo> _checkYtDlp() async {
    final latest = await _fetchReleaseJson(_ytDlpLatestRelease);
    final latestTag = _normalizeVersion(latest['tag_name']?.toString() ?? '');
    final latestNotes = latest['body']?.toString() ?? '';
    final currentPath = ytdlpPathNotifier.value.trim();
    final currentVersion = await _readExecutableVersion(currentPath, [
      '--version',
    ]);
    final installed = currentPath.isNotEmpty && File(currentPath).existsSync();
    final updateAvailable =
        installed &&
        currentVersion.isNotEmpty &&
        _isNewer(latestTag, currentVersion);

    return BinaryUpdateInfo(
      binary: ManagedBinary.ytDlp,
      isSupported: true,
      isInstalled: installed,
      updateAvailable: updateAvailable || !installed,
      currentVersion: installed ? currentVersion : 'Not installed',
      latestVersion: latestTag,
      installedPath: currentPath,
      releaseUrl: latest['html_url']?.toString() ?? '',
      releaseNotes: latestNotes,
    );
  }

  Future<BinaryUpdateInfo> _checkFfmpeg() async {
    final latest = await _fetchReleaseJson(_ffmpegLatestRelease);
    final latestVersion = latest['name']?.toString().trim().isNotEmpty == true
        ? latest['name'].toString()
        : latest['tag_name']?.toString() ?? 'Latest';
    final latestPublishedAt = latest['published_at']?.toString() ?? '';
    final currentPath = ffmpegPathNotifier.value.trim();
    final installed = currentPath.isNotEmpty && File(currentPath).existsSync();
    final storedVersion = ffmpegVersionNotifier.value.trim();
    final detectedVersion = await _readExecutableVersion(currentPath, [
      '-version',
    ]);
    final currentVersion = storedVersion.isNotEmpty
        ? storedVersion
        : detectedVersion;
    final updateAvailable = installed
        ? currentVersion.isEmpty || currentVersion != latestPublishedAt
        : true;

    return BinaryUpdateInfo(
      binary: ManagedBinary.ffmpeg,
      isSupported: _supportsFfmpegUpdate,
      isInstalled: installed,
      updateAvailable: updateAvailable,
      currentVersion: currentVersion.isEmpty ? 'Unknown' : currentVersion,
      latestVersion: latestPublishedAt.isEmpty
          ? latestVersion
          : latestPublishedAt,
      installedPath: currentPath,
      releaseUrl: latest['html_url']?.toString() ?? '',
      releaseNotes: latest['body']?.toString() ?? '',
    );
  }

  Future<BinaryInstallResult> _installYtDlp({
    void Function(double progress)? onProgress,
  }) async {
    final latest = await _fetchReleaseJson(_ytDlpLatestRelease);
    final version = _normalizeVersion(latest['tag_name']?.toString() ?? '');
    final downloadUrl = _ytDlpDownloadUrl();
    final targetPath = await _resolveYtDlpInstallPath(downloadUrl);
    await _downloadToFile(downloadUrl, targetPath, onProgress: onProgress);
    await _makeExecutableIfNeeded(targetPath);

    ytdlpPathNotifier.value = targetPath;
    ytdlpVersionNotifier.value = version;
    return BinaryInstallResult(path: targetPath, version: version);
  }

  Future<BinaryInstallResult> _installFfmpegWindows({
    void Function(double progress)? onProgress,
  }) async {
    if (!_supportsFfmpegUpdate) {
      throw UnsupportedError(
        'FFmpeg updater is currently supported on Windows only.',
      );
    }

    final latest = await _fetchReleaseJson(_ffmpegLatestRelease);
    final releaseVersion =
        latest['published_at']?.toString() ??
        latest['name']?.toString() ??
        'Latest';
    final asset = _selectFfmpegAsset(
      latest['assets'] as List<dynamic>? ?? const [],
    );
    final downloadUrl = asset['browser_download_url']?.toString();
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw StateError('FFmpeg release asset not found.');
    }

    final installRoot = await _resolveFfmpegInstallRoot();
    if (await installRoot.exists()) {
      await installRoot.delete(recursive: true);
    }
    await installRoot.create(recursive: true);

    final zipPath = '${installRoot.path}${Platform.pathSeparator}ffmpeg.zip';
    await _downloadToFile(downloadUrl, zipPath, onProgress: onProgress);

    final extractDir = Directory(
      '${installRoot.path}${Platform.pathSeparator}extract',
    );
    await extractDir.create(recursive: true);
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    extractArchiveToDisk(archive, extractDir.path);

    final binDir = await _locateFfmpegBinDirectory(extractDir);
    if (binDir == null) {
      throw StateError(
        'Could not find FFmpeg binaries in the downloaded archive.',
      );
    }

    final finalBinDir = Directory(
      '${installRoot.path}${Platform.pathSeparator}bin',
    );
    await _copyDirectory(binDir, finalBinDir);

    final ffmpegExe = File(
      '${finalBinDir.path}${Platform.pathSeparator}ffmpeg.exe',
    );
    if (!await ffmpegExe.exists()) {
      throw StateError('FFmpeg executable was not installed correctly.');
    }

    ffmpegPathNotifier.value = ffmpegExe.path;
    ffmpegVersionNotifier.value = releaseVersion;
    try {
      await File(zipPath).delete();
    } catch (_) {}
    try {
      await extractDir.delete(recursive: true);
    } catch (_) {}

    return BinaryInstallResult(path: ffmpegExe.path, version: releaseVersion);
  }

  Future<Map<String, dynamic>> _fetchReleaseJson(String url) async {
    final response = await _dio.get<String>(url);
    if (response.statusCode != 200 || response.data == null) {
      throw StateError('Failed to fetch release metadata.');
    }
    return jsonDecode(response.data!) as Map<String, dynamic>;
  }

  String _ytDlpDownloadUrl() {
    if (Platform.isWindows) return _ytDlpLatestWindows;
    if (Platform.isLinux) return _ytDlpLatestLinux;
    return _ytDlpLatestMac;
  }

  Future<String> _resolveYtDlpInstallPath(String downloadUrl) async {
    final supportDir = await getApplicationSupportDirectory();
    final binDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}binaries${Platform.pathSeparator}yt-dlp',
    );
    await binDir.create(recursive: true);

    final fileName = downloadUrl.endsWith('.exe') ? 'yt-dlp.exe' : 'yt-dlp';
    return '${binDir.path}${Platform.pathSeparator}$fileName';
  }

  Future<Directory> _resolveFfmpegInstallRoot() async {
    final supportDir = await getApplicationSupportDirectory();
    final root = Directory(
      '${supportDir.path}${Platform.pathSeparator}binaries${Platform.pathSeparator}ffmpeg',
    );
    return root;
  }

  Future<String?> _locateFfmpegBinDirectory(Directory root) async {
    await for (final entity in root.list(recursive: true)) {
      if (entity is File &&
          entity.path.toLowerCase().endsWith(
            '${Platform.pathSeparator}ffmpeg.exe',
          )) {
        return Directory(File(entity.path).parent.path);
      }
    }
    return null;
  }

  Map<String, dynamic> _selectFfmpegAsset(List<dynamic> assets) {
    for (final asset in assets.whereType<Map<String, dynamic>>()) {
      final name = asset['name']?.toString().toLowerCase() ?? '';
      if (name.contains('win64') && name.endsWith('.zip')) {
        return asset;
      }
    }
    throw StateError('No compatible FFmpeg asset found for this platform.');
  }

  Future<void> _downloadToFile(
    String url,
    String path, {
    void Function(double progress)? onProgress,
  }) async {
    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(responseType: ResponseType.stream),
    );
    if (response.statusCode != 200 || response.data == null) {
      throw StateError('Download failed for $url');
    }

    final total = response.headers.value(Headers.contentLengthHeader);
    final length = int.tryParse(total ?? '') ?? -1;
    final sink = File(path).openWrite();
    int received = 0;
    try {
      await for (final chunk in response.data!.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (length > 0) {
          onProgress?.call(received / length);
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  Future<String> _readExecutableVersion(String path, List<String> args) async {
    if (path.isEmpty || !File(path).existsSync()) return '';
    try {
      final result = await Process.run(path, args);
      if (result.exitCode != 0) return '';
      return result.stdout.toString().trim().split('\n').first.trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _makeExecutableIfNeeded(String path) async {
    if (Platform.isWindows) return;
    try {
      await Process.run('chmod', ['755', path]);
    } catch (_) {}
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relativePath = entity.path.substring(source.path.length);
      final destinationPath = '${target.path}$relativePath';
      if (entity is Directory) {
        await Directory(destinationPath).create(recursive: true);
      } else if (entity is File) {
        await File(destinationPath).parent.create(recursive: true);
        await entity.copy(destinationPath);
      }
    }
  }

  String _normalizeVersion(String version) => version.trim().startsWith('v')
      ? version.trim().substring(1)
      : version.trim();

  bool _isNewer(String latest, String current) {
    final latestParts = _splitVersion(latest);
    final currentParts = _splitVersion(current);
    final length = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;

    for (var i = 0; i < length; i++) {
      final latestVal = i < latestParts.length ? latestParts[i] : 0;
      final currentVal = i < currentParts.length ? currentParts[i] : 0;
      if (latestVal > currentVal) return true;
      if (latestVal < currentVal) return false;
    }
    return false;
  }

  List<int> _splitVersion(String value) {
    return value.split('.').map((part) {
      final digits = part.replaceAll(RegExp(r'\D'), '');
      return int.tryParse(digits) ?? 0;
    }).toList();
  }
}
