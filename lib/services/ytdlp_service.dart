import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../globals.dart';

enum DownloadType { videoWithAudio, videoOnly, audioOnly }

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

  List<DownloadOption> optionsFor(DownloadType type) => optionsByType[type] ?? const [];
}

class DownloadResult {
  final String savedPath;
  final String message;

  const DownloadResult({required this.savedPath, required this.message});
}

class YtdlpService {
  final _yt = YoutubeExplode();
  final _dio = Dio(BaseOptions(
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Accept': '*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Connection': 'keep-alive',
      'sec-ch-ua': '"Google Chrome";v="119", "Chromium";v="119", "Not?A_Brand";v="24"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
    },
    followRedirects: true,
    maxRedirects: 10,
    validateStatus: (status) => status != null && status < 500,
  ));

  bool get _canUseDesktopYtDlp {
    if (kIsWeb) return false;
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return false;
    final path = ytdlpPathNotifier.value.trim();
    return path.isNotEmpty && File(path).existsSync();
  }

  Future<VideoMetadata?> getMetadata(String url) async {
    if (_canUseDesktopYtDlp) {
      try { return await _getMetadataWithYtDlp(url); } catch (e) { debugPrint('yt-dlp meta error: $e'); }
    }
    try { return await _getMetadataWithYoutubeExplode(url); } catch (e) { debugPrint('Explode meta error: $e'); return null; }
  }

  Future<DownloadResult> download({
    required VideoMetadata metadata,
    required DownloadOption option,
    DownloadOption? audioOptionForMerge,
    void Function(double progress)? onProgress,
  }) async {
    if (_canUseDesktopYtDlp) {
      return await _downloadWithYtDlp(
        metadata: metadata,
        videoOption: option,
        audioOption: audioOptionForMerge,
        onProgress: onProgress,
      );
    }

    return _downloadWithYoutubeExplode(
      metadata: metadata,
      option: option,
      onProgress: onProgress,
    );
  }

  Future<VideoMetadata> _getMetadataWithYoutubeExplode(String url) async {
    final id = VideoId.parseVideoId(url);
    if (id == null) throw const FormatException('Invalid video URL');

    final video = await _yt.videos.get(id);
    final manifest = await _yt.videos.streamsClient.getManifest(id);

    final muxed = manifest.muxed.toList()..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
    final videoOnly = manifest.videoOnly.toList()..sort((a, b) => b.videoResolution.height.compareTo(a.videoResolution.height));
    final audioOnly = manifest.audioOnly.toList()..sort((a, b) => (b.bitrate.bitsPerSecond).compareTo(a.bitrate.bitsPerSecond));

    return VideoMetadata(
      id: video.id.value,
      sourceUrl: url,
      title: video.title,
      author: video.author,
      duration: video.duration ?? Duration.zero,
      thumbnailUrl: video.thumbnails.highResUrl,
      optionsByType: {
        DownloadType.videoWithAudio: muxed.map((s) => _fromStream(s, DownloadType.videoWithAudio)).toList(),
        DownloadType.videoOnly: videoOnly.map((s) => _fromStream(s, DownloadType.videoOnly)).toList(),
        DownloadType.audioOnly: audioOnly.map((s) => _fromStream(s, DownloadType.audioOnly)).toList(),
      },
    );
  }

  DownloadOption _fromStream(StreamInfo s, DownloadType type) {
    if (s is VideoStreamInfo) {
      return DownloadOption(
        id: s.tag.toString(),
        type: type,
        label: '${s.qualityLabel} (${s.container.name.toUpperCase()})',
        details: '${s.size.totalMegaBytes.toStringAsFixed(1)} MB | ${s.framerate.framesPerSecond.round()}fps',
        container: s.container.name,
        height: s.videoResolution.height,
        fileSizeBytes: s.size.totalBytes,
      );
    } else if (s is AudioStreamInfo) {
      return DownloadOption(
        id: s.tag.toString(),
        type: type,
        label: '${s.bitrate.kiloBitsPerSecond.round()} kbps (${s.container.name.toUpperCase()})',
        details: '${s.size.totalMegaBytes.toStringAsFixed(1)} MB',
        container: s.container.name,
        bitrateKbps: s.bitrate.kiloBitsPerSecond.round(),
        fileSizeBytes: s.size.totalBytes,
      );
    }
    throw UnimplementedError();
  }

  Future<VideoMetadata> _getMetadataWithYtDlp(String url) async {
    final result = await Process.run(ytdlpPathNotifier.value.trim(), ['--dump-single-json', '--no-playlist', url]);
    if (result.exitCode != 0) throw ProcessException('yt-dlp', [], result.stderr);

    final raw = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final formats = (raw['formats'] as List? ?? []).whereType<Map<String, dynamic>>().toList();

    final optionsByType = <DownloadType, List<DownloadOption>>{
      DownloadType.videoWithAudio: [],
      DownloadType.videoOnly: [],
      DownloadType.audioOnly: [],
    };

    for (final f in formats) {
      final hasVideo = f['vcodec'] != 'none' && f['vcodec'] != null;
      final hasAudio = f['acodec'] != 'none' && f['acodec'] != null;
      if (!hasVideo && !hasAudio) continue;

      final type = hasVideo && hasAudio ? DownloadType.videoWithAudio : hasVideo ? DownloadType.videoOnly : DownloadType.audioOnly;
      final height = _toInt(f['height']);
      final bitrate = _toInt(f['abr']) ?? _toInt(f['tbr']);
      final size = _toInt(f['filesize']) ?? _toInt(f['filesize_approx']);
      final ext = (f['ext'] as String? ?? 'mp4').toLowerCase();
      final formatId = f['format_id']?.toString();

      optionsByType[type]!.add(DownloadOption(
        id: formatId ?? '${type.name}-${height ?? bitrate}',
        type: type,
        label: _buildLabel(type, height, bitrate, ext, f['format_note'] ?? ''),
        details: _formatSize(size),
        container: ext,
        formatId: formatId,
        height: height,
        bitrateKbps: bitrate,
        fileSizeBytes: size,
      ));
    }

    // Sort
    for (var type in optionsByType.keys) {
      optionsByType[type]!.sort((a, b) => (b.height ?? b.bitrateKbps ?? 0).compareTo(a.height ?? a.bitrateKbps ?? 0));
    }

    return VideoMetadata(
      id: raw['id']?.toString() ?? '',
      sourceUrl: url,
      title: raw['title'] ?? 'Unknown',
      author: raw['uploader'] ?? 'Unknown',
      duration: Duration(seconds: _toInt(raw['duration']) ?? 0),
      thumbnailUrl: raw['thumbnail'] ?? '',
      optionsByType: optionsByType,
    );
  }

  String _buildLabel(DownloadType t, int? h, int? b, String e, String n) {
    if (t == DownloadType.audioOnly) return '${b ?? 'Audio'} kbps (${e.toUpperCase()})';
    return '${h ?? 'Video'}p ${n.isNotEmpty ? '[$n]' : ''} (${e.toUpperCase()})';
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return 'Unknown size';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<DownloadResult> _downloadWithYoutubeExplode({
    required VideoMetadata metadata,
    required DownloadOption option,
    void Function(double progress)? onProgress,
  }) async {
    final manifest = await _yt.videos.streamsClient.getManifest(metadata.id);
    final file = await _resolveTargetFile(metadata, option);
    
    StreamInfo stream;
    if (option.type == DownloadType.videoWithAudio) {
      stream = manifest.muxed.firstWhere((s) => s.tag.toString() == option.id);
    } else if (option.type == DownloadType.videoOnly) {
      stream = manifest.videoOnly.firstWhere((s) => s.tag.toString() == option.id);
    } else {
      stream = manifest.audioOnly.firstWhere((s) => s.tag.toString() == option.id);
    }

    final streamContent = _yt.videos.streamsClient.get(stream);
    final output = file.openWrite();
    int downloaded = 0;
    final total = stream.size.totalBytes;

    try {
      await for (final chunk in streamContent) {
        downloaded += chunk.length;
        output.add(chunk);
        onProgress?.call(downloaded / total);
      }
    } finally {
      await output.flush();
      await output.close();
    }

    return _finalizeDownload(option: option, file: file);
  }

  Future<DownloadResult> _downloadWithYtDlp({
    required VideoMetadata metadata,
    required DownloadOption videoOption,
    DownloadOption? audioOption,
    void Function(double progress)? onProgress,
  }) async {
    final file = await _resolveTargetFile(metadata, videoOption);
    final formats = audioOption != null ? '${videoOption.formatId}+${audioOption.formatId}' : videoOption.formatId!;
    
    final args = ['--no-playlist', '-f', formats, '-o', file.path];

    final ariaPath = aria2cPathNotifier.value.trim();
    if (ariaPath.isNotEmpty && File(ariaPath).existsSync()) {
      args.addAll(['--external-downloader', 'aria2c', '--external-downloader-args', 'aria2c:"-x 16 -s 16 -k 1M"']);
    }

    final ffmpegPath = ffmpegPathNotifier.value.trim();
    if (ffmpegPath.isNotEmpty && File(ffmpegPath).existsSync()) {
      args.addAll(['--ffmpeg-location', ffmpegPath]);
    }

    args.add(metadata.sourceUrl);

    final process = await Process.start(ytdlpPathNotifier.value.trim(), args, runInShell: false);
    final progressRegex = RegExp(r'(\d+(?:\.\d+)?)%');

    await for (final chunk in process.stdout.transform(utf8.decoder)) {
      final match = progressRegex.allMatches(chunk);
      if (match.isNotEmpty) {
        final val = double.tryParse(match.last.group(1) ?? '');
        if (val != null) onProgress?.call(val / 100);
      }
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) throw ProcessException('yt-dlp', args, 'Exit $exitCode');

    return _finalizeDownload(option: videoOption, file: file);
  }

  Future<DownloadResult> _finalizeDownload({required DownloadOption option, required File file}) async {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (isMobile && option.type != DownloadType.audioOnly) {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putVideo(file.path, album: albumNotifier.value);
      if (await file.exists()) await file.delete();
      return const DownloadResult(savedPath: '', message: 'Saved to gallery');
    }
    return DownloadResult(savedPath: file.path, message: 'Saved to ${file.path}');
  }

  Future<File> _resolveTargetFile(VideoMetadata metadata, DownloadOption option) async {
    final dir = await _resolveStorageDir();
    final safeTitle = metadata.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final ext = option.container.isEmpty ? 'mp4' : option.container;
    final path = '${dir.path}${Platform.pathSeparator}$safeTitle [${metadata.id}].$ext';
    return File(path);
  }

  Future<Directory> _resolveStorageDir() async {
    final custom = customPathNotifier.value.trim();
    if (custom.isNotEmpty) {
      final d = Directory(custom);
      if (await d.exists()) return d;
    }

    if (!kIsWeb && Platform.isWindows) return (await getDownloadsDirectory()) ?? await getApplicationDocumentsDirectory();
    if (!kIsWeb && Platform.isAndroid) return (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
    return getApplicationDocumentsDirectory();
  }

  int? _toInt(dynamic v) => v is int ? v : v is double ? v.round() : v is String ? int.tryParse(v) : null;
  void dispose() => _yt.close();
}
