import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/primary_button.dart';
import '../widgets/option_card.dart';
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 3D Smooth White Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.5, -0.6),
                radius: 1.5,
                colors: [
                  Colors.white,
                  Color(0xFFF8F9FA),
                  Color(0xFFE9ECEF),
                ],
                stops: [0.0, 0.4, 1.0],
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
                              color: const Color(0xFF1A1A1A),
                            ),
                          ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
                        ],
                      ),
                      _buildHeaderButton(LucideIcons.history),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  Text(
                    'Your personal video companion.',
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF1A1A1A).withOpacity(0.5),
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2),
                  
                  const SizedBox(height: 48),
                  
                  // URL Input Card
                  GlassContainer(
                    blur: 20,
                    opacity: 0.4,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          TextField(
                            controller: _urlController,
                            style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Paste video link here...',
                              hintStyle: TextStyle(color: const Color(0xFF1A1A1A).withOpacity(0.3)),
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
                  
                  const SizedBox(height: 40),
                  
                  // Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fast Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        'All Settings',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF1A1A1A).withOpacity(0.3),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 600.ms),
                  
                  const SizedBox(height: 16),
                  
                  // Grid of options or Shimmer
                  _buildOptionGrid(),
                  
                  const SizedBox(height: 40),
                  
                  // Info Box
                  GlassContainer(
                    width: double.infinity,
                    blur: 10,
                    opacity: 0.4,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.info, color: Color(0xFFFF0000), size: 20),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Support for 1000+ platforms including YouTube, Instagram, and TikTok.',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF1A1A1A).withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 1000.ms),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: const [
        OptionCard(
          title: 'Video Only',
          icon: LucideIcons.video,
          color: Color(0xFFFF0000),
        ),
        OptionCard(
          title: 'Audio (MP3)',
          icon: LucideIcons.music,
          color: Colors.orange,
        ),
        OptionCard(
          title: 'Shorts',
          icon: LucideIcons.zap,
          color: Colors.amber,
        ),
        OptionCard(
          title: 'Playlist',
          icon: LucideIcons.listVideo,
          color: Colors.blue,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.05),
      highlightColor: Colors.white.withOpacity(0.1),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.5,
        children: List.generate(4, (index) => GlassContainer(
          blur: 0,
          opacity: 1,
          borderRadius: BorderRadius.circular(24),
          child: Container(),
        )),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return GlassContainer(
      blur: 20,
      opacity: 0.5,
      borderRadius: BorderRadius.circular(32),
      border: Border.all(color: Colors.white),
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
                      color: Colors.black45,
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
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'by ${_metadata!.author}',
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A).withOpacity(0.5),
                    ),
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

  Widget _buildHeaderButton(IconData icon) {
    return GlassContainer(
      blur: 10,
      opacity: 0.4,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: const Color(0xFF1A1A1A).withOpacity(0.8), size: 20),
      ),
    );
  }
}
