import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'package:shimmer/shimmer.dart';
import '../main.dart';
import '../widgets/primary_button.dart';
import '../services/ytdlp_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:gal/gal.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Theme-aware Smooth Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.5, -0.6),
                radius: 1.5,
                colors: isDark 
                  ? [const Color(0xFF1E1E1E), const Color(0xFF121212), const Color(0xFF0F0F0F)]
                  : [Colors.white, const Color(0xFFF8F9FA), const Color(0xFFE9ECEF)],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            height: 48,
                            width: 48,
                          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                          const SizedBox(width: 12),
                          Text(
                            'YVD',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
                        ],
                      ),
                      _buildHeaderButton(LucideIcons.history, isDark, onPressed: () {}),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  Text(
                    'Your personal video companion.',
                    style: TextStyle(
                      fontSize: 16,
                      color: (isDark ? Colors.white : const Color(0xFF1A1A1A)).withOpacity(0.5),
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2),
                  
                  const SizedBox(height: 48),
                  
                  // URL Input Card
                  GlassContainer(
                    blur: 20,
                    opacity: isDark ? 0.2 : 0.4,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.white),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          TextField(
                            controller: _urlController,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A1A), fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Paste video link here...',
                              hintStyle: TextStyle(color: (isDark ? Colors.white : const Color(0xFF1A1A1A)).withOpacity(0.3)),
                              border: InputBorder.none,
                              icon: const Icon(LucideIcons.link, color: Color(0xFFFF0000)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          PrimaryButton(
                            label: 'ANALYZE URL',
                            isLoading: _isAnalyzing,
                            onPressed: _analyzeUrl,
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
                  
                  const SizedBox(height: 32),
                  
                  // Media Preview Card
                  if (_metadata != null)
                    _buildPreviewCard(),
                  
                    _buildPreviewCard(),
                  
                  const SizedBox(height: 100), // Reserve some space
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPreviewCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GlassContainer(
      blur: 20,
      opacity: isDark ? 0.3 : 0.5,
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: isDark ? Colors.white10 : Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    _metadata!.thumbnailUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                if (_isDownloading)
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(24),
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Select Quality', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _metadata!.qualities.map((q) {
                      final isSelected = _selectedQuality == q;
                      return ChoiceChip(
                        label: Text(q.toString().split('.').last.replaceAll('p', '') + 'p'),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _selectedQuality = q),
                        selectedColor: const Color(0xFFFF0000),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                          fontSize: 11,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
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
