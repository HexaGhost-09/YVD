import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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
                      _buildHeaderButton(Icons.history_rounded),
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
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        TextField(
                          controller: _urlController,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Paste video link here...',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                            border: InputBorder.none,
                            icon: const Icon(Icons.link_rounded, color: Color(0xFFFF0000)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: 'ANALYZE URL',
                          onPressed: () {},
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
                        'Settings',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 600.ms),
                  
                  const SizedBox(height: 16),
                  
                  // Grid of options
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      const OptionCard(
                        title: 'Video Only',
                        icon: Icons.videocam_rounded,
                        color: Color(0xFFFF0000),
                      ),
                      const OptionCard(
                        title: 'Audio (MP3)',
                        icon: Icons.audiotrack_rounded,
                        color: Colors.orange,
                      ),
                      const OptionCard(
                        title: 'Shorts',
                        icon: Icons.bolt_rounded,
                        color: Colors.amber,
                      ),
                      const OptionCard(
                        title: 'Playlist',
                        icon: Icons.playlist_play_rounded,
                        color: Colors.blue,
                      ),
                    ],
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),
                  
                  const SizedBox(height: 40),
                  
                  // Info Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF0000).withOpacity(0.1),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFFF0000)),
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

  Widget _buildHeaderButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}
