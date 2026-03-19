import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_service.dart';
import '../services/ytdlp_service.dart';
import '../widgets/primary_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final YtdlpService _ytdlpService = YtdlpService();

  bool _isAnalyzing = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  VideoMetadata? _metadata;
  DownloadType _selectedType = DownloadType.videoWithAudio;
  DownloadOption? _selectedOption;
  DownloadOption? _selectedAudioOption;
  GitHubRelease? _newUpdate;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _ytdlpService.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    final update = await UpdateService().checkForUpdate();
    if (mounted) setState(() => _newUpdate = update);
  }

  Future<void> _analyzeUrl() async {
    if (_urlController.text.isEmpty) return;
    setState(() { _isAnalyzing = true; _metadata = null; });
    final meta = await _ytdlpService.getMetadata(_urlController.text);
    if (!mounted) return;
    setState(() {
      _isAnalyzing = false;
      _metadata = meta;
      if (meta != null) {
        _selectedType = DownloadType.videoWithAudio;
        final vOptions = meta.optionsFor(DownloadType.videoOnly);
        final aOptions = meta.optionsFor(DownloadType.audioOnly);
        final vaOptions = meta.optionsFor(DownloadType.videoWithAudio);
        
        if (vaOptions.isNotEmpty) {
          _selectedOption = vaOptions.first;
          _selectedAudioOption = null;
        } else if (vOptions.isNotEmpty && aOptions.isNotEmpty) {
          _selectedOption = vOptions.first;
          _selectedAudioOption = aOptions.first;
        } else {
          _selectedOption = _firstAvailableOption(meta);
          _selectedType = _selectedOption?.type ?? DownloadType.videoOnly;
        }
      }
    });
    if (meta == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL or platform not supported.')));
  }

  DownloadOption? _firstAvailableOption(VideoMetadata? metadata) {
    if (metadata == null) return null;
    for (final type in DownloadType.values) {
      final options = metadata.optionsFor(type);
      if (options.isNotEmpty) return options.first;
    }
    return null;
  }

  Future<void> _startDownload() async {
    if (_metadata == null || _selectedOption == null || _isDownloading) return;
    setState(() { _isDownloading = true; _downloadProgress = 0.0; });
    try {
      final result = await _ytdlpService.download(
        metadata: _metadata!,
        option: _selectedOption!,
        audioOptionForMerge: _selectedAudioOption,
        onProgress: (p) => setState(() => _downloadProgress = p),
      );
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  void _selectType(DownloadType type) {
    setState(() {
      _selectedType = type;
      final options = _metadata?.optionsFor(type) ?? [];
      _selectedOption = options.isNotEmpty ? options.first : null;
      if (type == DownloadType.videoWithAudio && options.isEmpty) {
        final v = _metadata?.optionsFor(DownloadType.videoOnly) ?? [];
        final a = _metadata?.optionsFor(DownloadType.audioOnly) ?? [];
        _selectedOption = v.isNotEmpty ? v.first : null;
        _selectedAudioOption = a.isNotEmpty ? a.first : null;
      } else {
        _selectedAudioOption = null;
      }
    });
  }

  Future<void> _showQualityMenu(bool isAudio) async {
    final type = isAudio ? DownloadType.audioOnly : (
      _selectedType == DownloadType.videoWithAudio && _selectedAudioOption != null 
      ? DownloadType.videoOnly 
      : _selectedType
    );
    final options = _metadata?.optionsFor(type) ?? [];
    if (options.isEmpty) return;

    final selected = await showModalBottomSheet<DownloadOption>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          shrinkWrap: true,
          children: [
            Text(isAudio ? 'Choose audio quality' : 'Choose video quality', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...options.map((o) => RadioListTile<DownloadOption>(
              visualDensity: VisualDensity.compact,
              value: o,
              groupValue: isAudio ? _selectedAudioOption : _selectedOption,
              onChanged: (v) => Navigator.pop(context, v),
              title: Text(o.label),
              subtitle: Text(o.details),
            )),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => isAudio ? _selectedAudioOption = selected : _selectedOption = selected);
    }
  }

  String _downloadTypeLabel(DownloadType type) {
    switch (type) {
      case DownloadType.videoWithAudio: return 'V+A';
      case DownloadType.videoOnly: return 'Video';
      case DownloadType.audioOnly: return 'Audio';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: scheme.surface)),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              children: [
                if (_newUpdate != null) _buildUpdateBanner(context).animate().fadeIn(),
                const SizedBox(height: 20),
                _buildHeader(context),
                const SizedBox(height: 32),
                _buildSearchConsole(context),
                const SizedBox(height: 24),
                if (_metadata != null) _buildPreviewCard(context).animate().fadeIn().slideY(begin: 0.1),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(16)),
          child: Icon(LucideIcons.download, color: scheme.onPrimary, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YVD', style: Theme.of(context).textTheme.displaySmall),
            Text('Modern Video Downloader', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchConsole(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'Paste video link...',
              prefixIcon: Icon(LucideIcons.link),
              suffixIcon: _urlController.text.isNotEmpty ? IconButton(icon: Icon(LucideIcons.x), onPressed: () => setState(() => _urlController.clear())) : null,
            ),
            onChanged: (v) => setState(() {}),
            onSubmitted: (_) => _analyzeUrl(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isAnalyzing ? null : _analyzeUrl,
              icon: _isAnalyzing ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(LucideIcons.zap),
              label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze URL'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.network(_metadata!.thumbnailUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
              if (_isDownloading) Positioned.fill(child: Container(color: Colors.black54, child: Center(child: LoadingAnimationWidget.staggeredDotsWave(color: Colors.white, size: 40)))),
              Positioned(bottom: 0, left: 0, right: 0, child: LinearProgressIndicator(value: _isDownloading ? _downloadProgress : 0, backgroundColor: Colors.transparent)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_metadata!.title, style: textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text(_metadata!.author, style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                
                SegmentedButton<DownloadType>(
                  segments: DownloadType.values.map((t) => ButtonSegment(value: t, label: Text(_downloadTypeLabel(t)), icon: Icon(_typeIcon(t)))).toList(),
                  selected: {_selectedType},
                  onSelectionChanged: (set) => _selectType(set.first),
                ),
                const SizedBox(height: 24),

                _qualityPicker('Video Quality', _selectedOption, false),
                if (_selectedAudioOption != null) ...[
                  const SizedBox(height: 12),
                  _qualityPicker('Audio Quality', _selectedAudioOption, true),
                ],

                const SizedBox(height: 32),
                PrimaryButton(
                  label: _isDownloading ? 'Downloading ${(_downloadProgress*100).toInt()}%' : 'Download Now',
                  onPressed: _startDownload,
                  isLoading: _isDownloading,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qualityPicker(String label, DownloadOption? option, bool isAudio) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showQualityMenu(isAudio),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(isAudio ? LucideIcons.music : LucideIcons.video, size: 20, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(option?.label ?? 'Select quality', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronDown, size: 18),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(DownloadType t) {
    switch (t) {
      case DownloadType.videoWithAudio: return LucideIcons.clapperboard;
      case DownloadType.videoOnly: return LucideIcons.video;
      case DownloadType.audioOnly: return LucideIcons.music;
    }
  }

  Widget _buildUpdateBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: () => launchUrl(Uri.parse(_newUpdate!.htmlUrl)),
        leading: Icon(LucideIcons.gift, color: scheme.primary),
        title: Text('Update available: ${_newUpdate!.tagName}', style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Icon(LucideIcons.chevronRight, color: scheme.primary),
      ),
    );
  }
}
