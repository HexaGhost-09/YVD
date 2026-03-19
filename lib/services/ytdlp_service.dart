import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../globals.dart';

enum DownloadType { videoOnly, audioOnly }

class DownloadOption {
  final String id;
  final DownloadType type;
  final String label;
  final String details;
  final String container;
  final String? formatId;
  final int? height;
  final int? bitrateKbps;
  final int? fileSizeBytes;

  const DownloadOption({
    required this.id,
    required this.type,
    required this.label,
    required this.details,
    required this.container,
    this.formatId,
    this.height,
    this.bitrateKbps,
    this.fileSizeBytes,
  });
}

class VideoMetadata {
  final String id;
  final String sourceUrl;
  final String title;
  final String author;
  final Duration duration;
  final String thumbnailUrl;
  final Map<DownloadType, List<DownloadOption>> optionsByType;

  const VideoMetadata({
    required this.id,
    required this.sourceUrl,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.optionsByType,
  });

  List<DownloadOption> optionsFor(DownloadType type) =>
      optionsByType[type] ?? const [];
}

class DownloadResult {
  final String savedPath;
  final String message;

  const DownloadResult({required this.savedPath, required this.message});
}

class YtdlpService {
  final _yt = YoutubeExplode();
  final _dio = Dio();

  bool get _canUseDesktopYtDlp {
    if (kIsWeb) return false;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return false;
    }

    final path = ytdlpPathNotifier.value.trim();
    return path.isNotEmpty && File(path).existsSync();
  }

  Future<VideoMetadata?> getMetadata(String url) async {
    if (_canUseDesktopYtDlp) {
      try {
        return await _getMetadataWithYtDlp(url);
      } catch (e) {
        debugPrint('yt-dlp metadata fallback: $e');
      }
    }

    try {
      return await _getMetadataWithYoutubeExplode(url);
    } catch (e) {
      debugPrint('Explode metadata error: $e');
      return null;
    }
  }

  Future<DownloadResult> download({
    required VideoMetadata metadata,
    required DownloadOption option,
    void Function(double progress)? onProgress,
  }) async {
    if (_canUseDesktopYtDlp && option.formatId != null) {
      try {
        return await _downloadWithYtDlp(
          metadata: metadata,
          option: option,
          onProgress: onProgress,
        );
      } catch (e) {
        debugPrint('yt-dlp download fallback: $e');
      }
    }

    return _downloadWithYoutubeExplode(
      metadata: metadata,
      option: option,
      onProgress: onProgress,
    );
  }

  Future<VideoMetadata> _getMetadataWithYoutubeExplode(String url) async {
    final id = VideoId.parseVideoId(url);
    if (id == null) {
      throw const FormatException('Invalid video URL');
    }

    final video = await _yt.videos.get(id);
    final manifest = await _yt.videos.streamsClient.getManifest(id);

    final videoOnly = manifest.videoOnly.toList()
      ..sort(
        (a, b) => b.videoResolution.height.compareTo(a.videoResolution.height),
      );
    final audioOnly = manifest.audioOnly.toList()
      ..sort(
        (a, b) => (b.bitrate.bitsPerSecond).compareTo(a.bitrate.bitsPerSecond),
      );

    return VideoMetadata(
      id: video.id.value,
      sourceUrl: url,
      title: video.title,
      author: video.author,
      duration: video.duration ?? Duration.zero,
      thumbnailUrl: video.thumbnails.highResUrl,
      optionsByType: {
        DownloadType.videoOnly: _uniqueOptions(
          videoOnly.map(
            (stream) => DownloadOption(
              id: stream.tag.toString(),
              type: DownloadType.videoOnly,
              label:
                  '${stream.qualityLabel} (${stream.container.name.toUpperCase()})',
              details: _describeVideoStream(
                height: stream.videoResolution.height,
                fps: stream.framerate.framesPerSecond.round(),
                size: stream.size.totalBytes,
              ),
              container: stream.container.name,
              height: stream.videoResolution.height,
              fileSizeBytes: stream.size.totalBytes,
            ),
          ),
        ),
        DownloadType.audioOnly: _uniqueOptions(
          audioOnly.map(
            (stream) => DownloadOption(
              id: stream.tag.toString(),
              type: DownloadType.audioOnly,
              label:
                  '${stream.bitrate.kiloBitsPerSecond.round()} kbps (${stream.container.name.toUpperCase()})',
              details: _describeAudioStream(
                bitrateKbps: stream.bitrate.kiloBitsPerSecond.round(),
                size: stream.size.totalBytes,
              ),
              container: stream.container.name,
              bitrateKbps: stream.bitrate.kiloBitsPerSecond.round(),
              fileSizeBytes: stream.size.totalBytes,
            ),
          ),
        ),
      },
    );
  }

  Future<VideoMetadata> _getMetadataWithYtDlp(String url) async {
    final result = await Process.run(ytdlpPathNotifier.value.trim(), [
      '--dump-single-json',
      '--no-playlist',
      url,
    ]);

    if (result.exitCode != 0) {
      throw ProcessException(
        ytdlpPathNotifier.value.trim(),
        ['--dump-single-json', '--no-playlist', url],
        '${result.stderr}',
        result.exitCode,
      );
    }

    final raw = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final formats = (raw['formats'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((format) => format.map((key, value) => MapEntry('$key', value)))
        .toList();

    final optionsByType = <DownloadType, List<DownloadOption>>{
      DownloadType.videoOnly: [],
      DownloadType.audioOnly: [],
    };

    for (final format in formats) {
      final hasVideo = (format['vcodec'] as String? ?? 'none') != 'none';
      final hasAudio = (format['acodec'] as String? ?? 'none') != 'none';
      if (!hasVideo && !hasAudio) continue;

      final type = hasVideo
          ? DownloadType.videoOnly
          : DownloadType.audioOnly;

      final height = _toInt(format['height']);
      final bitrate = _toInt(format['abr']) ?? _toInt(format['tbr']);
      final size =
          _toInt(format['filesize']) ?? _toInt(format['filesize_approx']);
      final ext = (format['ext'] as String? ?? 'mp4').toLowerCase();
      final formatId = format['format_id']?.toString();
      final note = (format['format_note'] as String? ?? '').trim();
      final fps = _toInt(format['fps']);

      final option = DownloadOption(
        id: formatId ?? '${type.name}-${height ?? bitrate ?? ext}',
        type: type,
        label: _buildYtDlpLabel(
          type: type,
          height: height,
          bitrate: bitrate,
          ext: ext,
          note: note,
        ),
        details: type == DownloadType.audioOnly
            ? _describeAudioStream(bitrateKbps: bitrate, size: size)
            : _describeVideoStream(height: height, fps: fps, size: size),
        container: ext,
        formatId: formatId,
        height: height,
        bitrateKbps: bitrate,
        fileSizeBytes: size,
      );

      optionsByType[type]!.add(option);
    }

    for (final entry in optionsByType.entries) {
      entry.value.sort((a, b) {
        if (entry.key == DownloadType.audioOnly) {
          return (b.bitrateKbps ?? 0).compareTo(a.bitrateKbps ?? 0);
        }

        return (b.height ?? 0).compareTo(a.height ?? 0);
      });
      optionsByType[entry.key] = _uniqueOptions(entry.value);
    }

    return VideoMetadata(
      id: raw['id']?.toString() ?? '',
      sourceUrl: url,
      title: raw['title']?.toString() ?? 'Unknown title',
      author: raw['uploader']?.toString() ?? 'Unknown author',
      duration: Duration(seconds: _toInt(raw['duration']) ?? 0),
      thumbnailUrl: raw['thumbnail']?.toString() ?? '',
      optionsByType: optionsByType,
    );
  }

  Future<DownloadResult> _downloadWithYoutubeExplode({
    required VideoMetadata metadata,
    required DownloadOption option,
    void Function(double progress)? onProgress,
  }) async {
    final manifest = await _yt.videos.streamsClient.getManifest(metadata.id);
    final file = await _resolveTargetFile(metadata, option);

    final streamUrl = option.type == DownloadType.videoOnly
        ? manifest.videoOnly
              .firstWhere((stream) => stream.tag.toString() == option.id)
              .url
        : manifest.audioOnly
              .firstWhere((stream) => stream.tag.toString() == option.id)
              .url;

    await _dio.download(
      streamUrl.toString(),
      file.path,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call(received / total);
        }
      },
    );

    return _finalizeDownload(option: option, file: file);
  }

  Future<DownloadResult> _downloadWithYtDlp({
    required VideoMetadata metadata,
    required DownloadOption option,
    void Function(double progress)? onProgress,
  }) async {
    final file = await _resolveTargetFile(metadata, option);
    final args = <String>[
      '--no-playlist',
      '-f',
      option.formatId!,
      '-o',
      file.path,
    ];

    final ffmpegPath = ffmpegPathNotifier.value.trim();
    if (ffmpegPath.isNotEmpty && File(ffmpegPath).existsSync()) {
      args.addAll(['--ffmpeg-location', ffmpegPath]);
    }

    args.add(metadata.sourceUrl);

    final process = await Process.start(
      ytdlpPathNotifier.value.trim(),
      args,
      runInShell: false,
    );

    final progressRegex = RegExp(r'(\d+(?:\.\d+)?)%');
    final output = StringBuffer();

    Future<void> consume(Stream<List<int>> stream) async {
      await for (final chunk in stream.transform(utf8.decoder)) {
        output.write(chunk);
        for (final match in progressRegex.allMatches(chunk)) {
          final value = double.tryParse(match.group(1) ?? '');
          if (value != null) {
            onProgress?.call(value / 100);
          }
        }
      }
    }

    await Future.wait([consume(process.stdout), consume(process.stderr)]);

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw ProcessException(
        ytdlpPathNotifier.value.trim(),
        args,
        output.toString(),
        exitCode,
      );
    }

    return _finalizeDownload(option: option, file: file);
  }

  Future<DownloadResult> _finalizeDownload({
    required DownloadOption option,
    required File file,
  }) async {
    final mobileVideo =
        !kIsWeb &&
        (Platform.isAndroid || Platform.isIOS) &&
        option.type != DownloadType.audioOnly;

    if (mobileVideo) {
      final hasPermission = await Gal.hasAccess();
      if (!hasPermission) {
        await Gal.requestAccess();
      }

      await Gal.putVideo(file.path, album: albumNotifier.value);
      if (await file.exists()) {
        await file.delete();
      }

      return const DownloadResult(
        savedPath: '',
        message: 'Saved to your gallery successfully.',
      );
    }

    return DownloadResult(
      savedPath: file.path,
      message: 'Saved to ${file.path}',
    );
  }

  Future<File> _resolveTargetFile(
    VideoMetadata metadata,
    DownloadOption option,
  ) async {
    final baseDirectory = await _resolveOutputDirectory();
    final safeTitle = metadata.title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    final extension = option.container.isEmpty ? 'mp4' : option.container;
    final fileName =
        '$safeTitle [${metadata.id}] ${option.type.name}.$extension';
    return File('${baseDirectory.path}${Platform.pathSeparator}$fileName');
  }

  Future<Directory> _resolveOutputDirectory() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return downloads;
      }
    }

    if (!kIsWeb && Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        return directory;
      }
    }

    return getApplicationDocumentsDirectory();
  }

  List<DownloadOption> _uniqueOptions(Iterable<DownloadOption> input) {
    final seen = <String>{};
    final output = <DownloadOption>[];

    for (final option in input) {
      final key = '${option.type.name}-${option.label}-${option.container}';
      if (seen.add(key)) {
        output.add(option);
      }
    }

    return output;
  }

  String _buildYtDlpLabel({
    required DownloadType type,
    required int? height,
    required int? bitrate,
    required String ext,
    required String note,
  }) {
    if (type == DownloadType.audioOnly) {
      final label = bitrate != null ? '${bitrate.round()} kbps' : 'Audio';
      return '$label (${ext.toUpperCase()})';
    }

    final resolution = height != null
        ? '${height}p'
        : (note.isEmpty ? 'Video' : note);
    return '$resolution (${ext.toUpperCase()})';
  }

  String _describeVideoStream({
    required int? height,
    required int? fps,
    required int? size,
  }) {
    final parts = <String>[];
    if (height != null) {
      parts.add('${height}p');
    }
    if (fps != null) {
      parts.add('${fps}fps');
    }
    if (size != null) {
      parts.add(_formatBytes(size));
    }
    return parts.isEmpty ? 'Video stream' : parts.join(' | ');
  }

  String _describeAudioStream({required int? bitrateKbps, required int? size}) {
    final parts = <String>[];
    if (bitrateKbps != null) {
      parts.add('${bitrateKbps.round()} kbps');
    }
    if (size != null) {
      parts.add(_formatBytes(size));
    }
    return parts.isEmpty ? 'Audio stream' : parts.join(' | ');
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    return '${size.toStringAsFixed(size >= 100 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void dispose() {
    _yt.close();
  }
}
