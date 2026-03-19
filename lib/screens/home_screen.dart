import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/glow_background.dart';
import '../widgets/primary_button.dart';
import '../widgets/option_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _analyzeUrl() async {
    if (_urlController.text.isEmpty) return;
    
    setState(() => _isAnalyzing = true);
    // Simulate analysis
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _isAnalyzing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // Background Glows
          const GlowBackground(
            top: -100,
            right: -100,
            color: Color(0xFFFF0000),
            opacity: 0.15,
          ),
          const GlowBackground(
            bottom: -50,
            left: -50,
            color: Color(0xFF2196F3),
            opacity: 0.1,
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
                      Text(
                        'YVD',
                        style: GoogleFonts.outfit(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          color: Colors.white,
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),
                      _buildHeaderButton(LucideIcons.history),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  Text(
                    'Your personal video companion.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2),
                  
                  const SizedBox(height: 48),
                  
                  // URL Input Card
                  GlassContainer(
                    blur: 20,
                    opacity: 0.05,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextField(
                          controller: _urlController,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Paste video link here...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
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
                  ).animate().fadeIn(delay: 400.ms, duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
                  
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
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'All Settings',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 600.ms),
                  
                  const SizedBox(height: 16),
                  
                  // Grid of options or Shimmer
                  _isAnalyzing ? _buildShimmerGrid() : _buildOptionGrid(),
                  
                  const SizedBox(height: 40),
                  
                  // Info Box
                  GlassContainer(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    blur: 10,
                    opacity: 0.03,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.info, color: Color(0xFFFF0000), size: 20),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Support for 1000+ platforms including YouTube, Instagram, and TikTok.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildHeaderButton(IconData icon) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      blur: 10,
      opacity: 0.05,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withOpacity(0.1)),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
