import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoMetadata {
  final String id;
  final String title;
  final String author;
  final Duration duration;
  final String thumbnailUrl;
  final List<VideoQuality> qualities;

  VideoMetadata({
    required this.id,
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    required this.qualities,
  });
}

enum VideoQuality { p360, p720, p1080, best }

class YtdlpService {
  final _yt = YoutubeExplode();
  final _dio = Dio();

  Future<VideoMetadata?> getMetadata(String url) async {
    try {
      final id = VideoId.parseVideoId(url);
      if (id == null) return null;

      final video = await _yt.videos.get(id);
      final manifest = await _yt.videos.streamsClient.getManifest(id);
      
      // Filter for unique resolutions
      final qualities = manifest.muxed
          .map((s) => s.videoQuality.label)
          .toSet()
          .map((q) {
            if (q.contains('360')) return VideoQuality.p360;
            if (q.contains('720')) return VideoQuality.p720;
            if (q.contains('1080')) return VideoQuality.p1080;
            return VideoQuality.best;
          })
          .toList();

      return VideoMetadata(
        id: video.id.value,
        title: video.title,
        author: video.author,
        duration: video.duration ?? Duration.zero,
        thumbnailUrl: video.thumbnails.highResUrl,
        qualities: qualities,
      );
    } catch (e) {
      print('Error analysis: $e');
      return null;
    }
  }

  Future<void> downloadVideo(String videoId, {
    VideoQuality quality = VideoQuality.p720,
    void Function(double)? onProgress,
  }) async {
    try {
      // 1. Get stream info
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streamInfo = manifest.muxed.withHighestBitrate();
      
      if (streamInfo == null) throw 'No downloadable stream found';

      // 2. Prepare path
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$videoId.${streamInfo.container.name}';
      
      // 3. Download
      await _dio.download(
        streamInfo.url.toString(),
        path,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            onProgress?.call(count / total);
          }
        },
      );

      // 4. Save to Gallery
      final hasPermission = await Gal.hasAccess();
      if (!hasPermission) {
        await Gal.requestAccess();
      }
      
      await Gal.putVideo(path);
      
      // Cleanup
      final file = File(path);
      if (await file.exists()) await file.delete();

    } catch (e) {
      print('Download error: $e');
      rethrow;
    }
  }

  void dispose() {
    _yt.close();
  }
}
