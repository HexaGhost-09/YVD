import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/primary_button.dart';
import '../services/ytdlp_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cupertino_icons/cupertino_icons.dart';

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
  VideoQuality _selectedQuality = VideoQuality.p720;
  GitHubRelease? _newUpdate;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  void _checkForUpdates() async {
    final update = await UpdateService().checkForUpdate();
    if (mounted) setState(() => _newUpdate = update);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _ytdlpService.dispose();
    super.dispose();
  }

  void _analyzeUrl() async {
    if (_urlController.text.isEmpty) return;
    
    setState(() {
      _isAnalyzing = true;
      _metadata = null;
    });

    final meta = await _ytdlpService.getMetadata(_urlController.text);
    
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _metadata = meta;
      });
      
      if (meta == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid video URL or platform not supported.')),
        );
      }
    }
  }

  void _startDownload() async {
    if (_metadata == null || _isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      await _ytdlpService.downloadVideo(
        _metadata!.id,
        quality: _selectedQuality,
        onProgress: (p) => setState(() => _downloadProgress = p),
      );
      
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to your device successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed. Check your connection.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent, // Theme-aware gradient sits below
      body: Stack(
        children: [
          // Theme-aware Smooth Gradient Background (Subtler for 1.0.5)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark 
                  ? [const Color(0xFF1A1A1A), const Color(0xFF0F0F0F)]
                  : [const Color(0xFFFFFFFF), const Color(0xFFF2F2F7)],
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  
                  if (_newUpdate != null)
                    _buildUpdateBanner(),
                  
                  const SizedBox(height: 48),

                  // Header (iOS Style: Center Aligned)
                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 80,
                          width: 80,
                        ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                        const SizedBox(height: 24),
                        Text(
                          'YVD',
                          style: GoogleFonts.outfit(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                          ),
                        ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2),
                        const SizedBox(height: 8),
                        Text(
                          'Paste. Analyze. Download.',
                          style: TextStyle(
                            fontSize: 14,
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                            letterSpacing: 0.5,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 800.ms),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),
                  
                  // Modern iOS Search Pill
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: GlassContainer(
                      blur: 30,
                      opacity: isDark ? 0.15 : 0.5,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.white),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.link, color: Color(0xFFFF0000), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _urlController,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: 'Enter video URL',
                                  hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.2)),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _analyzeUrl(),
                              ),
                            ),
                            if (_isAnalyzing)
                              LoadingAnimationWidget.beat(color: const Color(0xFFFF0000), size: 24)
                            else
                              IconButton(
                                icon: const Icon(LucideIcons.arrowRight, color: Color(0xFFFF0000)),
                                onPressed: _analyzeUrl,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 800.ms).scale(begin: const Offset(0.9, 0.9)),
                  
                  const SizedBox(height: 48),
                  
                  // Media Preview Card
                  if (_metadata != null)
                    _buildPreviewCard(),
                  
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(_newUpdate!.htmlUrl)),
      child: GlassContainer(
        blur: 10,
        opacity: 0.1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF0000).withOpacity(0.3)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(LucideIcons.gift, color: Color(0xFFFF0000), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Update ${_newUpdate!.tagName} Available!',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const Icon(LucideIcons.externalLink, color: Color(0xFFFF0000), size: 16),
            ],
          ),
        ),
      ).animate().shake(),
    );
  }


  Widget _buildPreviewCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GlassContainer(
      blur: 40,
      opacity: isDark ? 0.2 : 0.5,
      borderRadius: BorderRadius.circular(36),
      border: Border.all(color: isDark ? Colors.white10 : Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.network(
                    _metadata!.thumbnailUrl,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
                if (_isDownloading)
                  Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LoadingAnimationWidget.staggeredDotsWave(
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(_downloadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _metadata!.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Quality',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _metadata!.qualities.map((q) {
                        final isSelected = _selectedQuality == q;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedQuality = q),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFF0000) : (isDark ? Colors.white05 : Colors.black.withOpacity(0.05)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              q.toString().split('.').last.replaceAll('p', '') + 'p',
                              style: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  PrimaryButton(
                    label: _isDownloading ? 'DOWNLOADING...' : 'DOWNLOAD VIDEO',
                    onPressed: _isDownloading ? () {} : _startDownload,
                    isLoading: _isDownloading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildHeaderButton(IconData icon, bool isDark, {VoidCallback? onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: GlassContainer(
        blur: 10,
        opacity: isDark ? 0.3 : 0.4,
        shape: BoxShape.circle,
        border: Border.all(color: isDark ? Colors.white10 : Colors.white),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: (isDark ? Colors.white : const Color(0xFF1A1A1A)).withOpacity(0.8), size: 20),
        ),
      ),
    );
  }
}
