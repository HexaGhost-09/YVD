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
    setState(() {
      _isAnalyzing = true;
      _metadata = null;
    });

    final meta = await _ytdlpService.getMetadata(_urlController.text);
    if (!mounted) return;

    setState(() {
      _isAnalyzing = false;
      _metadata = meta;
      final preferredOptions =
          meta?.optionsFor(DownloadType.videoWithAudio) ?? const [];
      _selectedOption = preferredOptions.isNotEmpty
          ? preferredOptions.first
          : _firstAvailableOption(meta);
      _selectedType = _selectedOption?.type ?? DownloadType.videoWithAudio;
    });

    if (meta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid video URL or platform not supported.')),
      );
    }
  }

  Future<void> _startDownload() async {
    if (_metadata == null || _selectedOption == null || _isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final result = await _ytdlpService.download(
        metadata: _metadata!,
        option: _selectedOption!,
        onProgress: (p) => setState(() => _downloadProgress = p),
      );
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed. Check your connection.')),
        );
      }
    }
  }

  DownloadOption? _firstAvailableOption(VideoMetadata? metadata) {
    if (metadata == null) return null;
    for (final type in DownloadType.values) {
      final options = metadata.optionsFor(type);
      if (options.isNotEmpty) return options.first;
    }
    return null;
  }

  void _selectType(DownloadType type) {
    final options = _metadata?.optionsFor(type) ?? const [];
    setState(() {
      _selectedType = type;
      _selectedOption = options.isNotEmpty ? options.first : null;
    });
  }

  Future<void> _showQualityMenu() async {
    final options = _metadata?.optionsFor(_selectedType) ?? const [];
    if (options.isEmpty) return;

    final selected = await showModalBottomSheet<DownloadOption>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shrinkWrap: true,
            children: [
              Text('Choose quality', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Available formats for ${_downloadTypeLabel(_selectedType)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ...options.map(
                (option) => RadioListTile<DownloadOption>(
                  value: option,
                  groupValue: _selectedOption,
                  onChanged: (value) => Navigator.pop(context, value),
                  title: Text(option.label),
                  subtitle: Text(option.details),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) setState(() => _selectedOption = selected);
  }

  String _downloadTypeLabel(DownloadType type) {
    switch (type) {
      case DownloadType.videoWithAudio:
        return 'Video + Audio';
      case DownloadType.videoOnly:
        return 'Video Only';
      case DownloadType.audioOnly:
        return 'Audio Only';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface,
                    scheme.primary.withOpacity(0.05),
                    scheme.surface,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              children: [
                if (_newUpdate != null)
                  _buildUpdateBanner(context).animate().fadeIn().scale(delay: 100.ms),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(LucideIcons.download, color: scheme.onPrimary, size: 28),
                    ).animate().scale(delay: 200.ms),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YVD', style: textTheme.displaySmall),
                        Text(
                          'Premium Video Downloader',
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Search Console
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withOpacity(0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'Paste video link here...',
                          prefixIcon: Icon(LucideIcons.link),
                          suffixIcon: _urlController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(LucideIcons.x),
                                  onPressed: () => setState(() => _urlController.clear()),
                                )
                              : null,
                        ),
                        onChanged: (v) => setState(() {}),
                        onSubmitted: (_) => _analyzeUrl(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isAnalyzing ? null : _analyzeUrl,
                          icon: _isAnalyzing
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(LucideIcons.zap),
                          label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze URL'),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                const SizedBox(height: 24),
                if (_metadata != null)
                  _buildPreviewCard(context).animate().fadeIn().slideY(begin: 0.05),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => launchUrl(Uri.parse(_newUpdate!.htmlUrl)),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.gift, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Update ${_newUpdate!.tagName} is here!',
                  style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: scheme.primary),
            ],
          ),
        ),
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
              Image.network(
                _metadata!.thumbnailUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isDownloading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LoadingAnimationWidget.staggeredDotsWave(
                          color: Colors.white,
                          size: 40,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${(_downloadProgress * 100).toInt()}%',
                          style: textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _metadata!.duration.inMinutes > 0
                            ? '${_metadata!.duration.inMinutes}:${(_metadata!.duration.inSeconds % 60).toString().padLeft(2, '0')}'
                            : 'Live',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _metadata!.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: scheme.tertiaryContainer,
                      child: Icon(LucideIcons.user, size: 14, color: scheme.onTertiaryContainer),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _metadata!.author,
                      style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Download Format', style: textTheme.titleSmall),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<DownloadType>(
                    segments: DownloadType.values.map((type) {
                      final enabled = _metadata!.optionsFor(type).isNotEmpty;
                      return ButtonSegment<DownloadType>(
                        value: type,
                        label: Text(_downloadTypeLabel(type)),
                        enabled: enabled,
                        icon: Icon(_typeIcon(type)),
                      );
                    }).toList(),
                    selected: {_selectedType},
                    onSelectionChanged: (set) => _selectType(set.first),
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Quality & Bits', style: textTheme.titleSmall),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _showQualityMenu,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.settings2, size: 20, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedOption?.label ?? 'Select quality',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (_selectedOption != null)
                                Text(
                                  _selectedOption!.details,
                                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        Icon(LucideIcons.chevronDown, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                PrimaryButton(
                  label: _isDownloading
                      ? 'Downloading...'
                      : 'Download Now',
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

  IconData _typeIcon(DownloadType type) {
    switch (type) {
      case DownloadType.videoWithAudio:
        return LucideIcons.video;
      case DownloadType.videoOnly:
        return LucideIcons.clapperboard;
      case DownloadType.audioOnly:
        return LucideIcons.music;
    }
  }
}
