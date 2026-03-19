import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import '../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // Parent provides background or isDark theme scaffold
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
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                const SizedBox(height: 32),
                Text(
                  'Settings',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 48),

                _buildGroupLabel(context, 'Appearance'),
                const SizedBox(height: 16),
                _buildSettingItem(
                  context,
                  title: 'Dark Mode',
                  subtitle: 'Use dark theme across the app',
                  icon: isDark ? LucideIcons.moon : LucideIcons.sun,
                  trailing: Switch(
                    value: isDark,
                    onChanged: (val) {
                      YVDApp.themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                    },
                    activeColor: const Color(0xFFFF0000),
                  ),
                ),

                const SizedBox(height: 32),
                _buildGroupLabel(context, 'Downloads'),
                const SizedBox(height: 16),
                _buildSettingItem(
                  context,
                  title: 'Storage Path',
                  subtitle: '/Gallery/Videos',
                  icon: LucideIcons.folderDown,
                ),
                const SizedBox(height: 12),
                _buildSettingItem(
                  context,
                  title: 'Clear History',
                  subtitle: 'Remove all past download links',
                  icon: LucideIcons.trash2,
                  isDestructive: true,
                ),

                const SizedBox(height: 32),
                _buildGroupLabel(context, 'App'),
                const SizedBox(height: 16),
                _buildSettingItem(
                  context,
                  title: 'About YVD',
                  subtitle: 'Version 1.0.5 Premium',
                  icon: LucideIcons.info,
                ),
                const SizedBox(height: 12),
                _buildSettingItem(
                  context,
                  title: 'Help & Support',
                  subtitle: 'Contact the developer',
                  icon: LucideIcons.helpCircle,
                ),
                
                const SizedBox(height: 60),
                Center(
                  child: Opacity(
                    opacity: 0.3,
                    child: Text(
                      'Made with ❤️ by HexaGhost',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupLabel(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      blur: 15,
      opacity: isDark ? 0.15 : 0.4,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: isDark ? Colors.white10 : Colors.white),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: isDestructive ? Colors.red : const Color(0xFFFF0000), size: 24),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: (isDark ? Colors.white : const Color(0xFF1A1A1A)).withOpacity(0.5),
            fontSize: 13,
          ),
        ),
        trailing: trailing ?? Icon(LucideIcons.chevronRight, size: 18, color: (isDark ? Colors.white : Colors.black).withOpacity(0.2)),
      ),
    );
  }
}
