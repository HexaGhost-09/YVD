import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../globals.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = "1.0.7";

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  void _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
  }

  void _showAlbumDialog(BuildContext context) {
    final controller = TextEditingController(text: albumNotifier.value);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Album Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g., YVD, MyVideos, etc.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              albumNotifier.value = controller.text.trim();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBinaryPathDialog({
    required BuildContext context,
    required String title,
    required String hint,
    required ValueNotifier<String> notifier,
  }) {
    final controller = TextEditingController(text: notifier.value);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              notifier.value = '';
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              notifier.value = controller.text.trim();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _manualUpdateCheck() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Checking for updates...')));
    final update = await UpdateService().checkForUpdate();
    if (!mounted) return;
    if (update != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('New Update ${update.tagName} Available!'),
          content: Text(update.body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () {
                launchUrl(
                  Uri.parse(update.htmlUrl),
                  mode: LaunchMode.externalApplication,
                );
                Navigator.pop(context);
              },
              child: const Text('Download'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are on the latest version.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final supportsDesktopBinaries =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.5, -0.6),
                radius: 1.5,
                colors: isDark
                    ? [
                        const Color(0xFF1E1E1E),
                        const Color(0xFF121212),
                        const Color(0xFF0F0F0F),
                      ]
                    : [
                        Colors.white,
                        const Color(0xFFF8F9FA),
                        const Color(0xFFE9ECEF),
                      ],
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
                ValueListenableBuilder(
                  valueListenable: themeNotifier,
                  builder: (context, theme, _) => _buildSettingItem(
                    context,
                    title: 'Dark Mode',
                    subtitle: 'Use dark theme across the app',
                    icon: theme == ThemeMode.dark
                        ? LucideIcons.moon
                        : LucideIcons.sun,
                    trailing: Switch(
                      value: theme == ThemeMode.dark,
                      onChanged: (val) {
                        themeNotifier.value = val
                            ? ThemeMode.dark
                            : ThemeMode.light;
                      },
                      activeThumbColor: const Color(0xFFFF0000),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                _buildGroupLabel(context, 'Downloads'),
                const SizedBox(height: 16),
                ValueListenableBuilder(
                  valueListenable: albumNotifier,
                  builder: (context, album, _) => _buildSettingItem(
                    context,
                    onTap: () => _showAlbumDialog(context),
                    title: 'Storage Path',
                    subtitle: '/Gallery/$album',
                    icon: LucideIcons.folderDown,
                  ),
                ),
                if (supportsDesktopBinaries) ...[
                  const SizedBox(height: 12),
                  ValueListenableBuilder(
                    valueListenable: ytdlpPathNotifier,
                    builder: (context, path, _) => _buildSettingItem(
                      context,
                      onTap: () => _showBinaryPathDialog(
                        context: context,
                        title: 'yt-dlp Path',
                        hint: r'C:\Tools\yt-dlp.exe',
                        notifier: ytdlpPathNotifier,
                      ),
                      title: 'yt-dlp Binary',
                      subtitle: path.isEmpty ? 'Not configured' : path,
                      icon: LucideIcons.terminalSquare,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder(
                    valueListenable: ffmpegPathNotifier,
                    builder: (context, path, _) => _buildSettingItem(
                      context,
                      onTap: () => _showBinaryPathDialog(
                        context: context,
                        title: 'FFmpeg Path',
                        hint: r'C:\Tools\ffmpeg.exe',
                        notifier: ffmpegPathNotifier,
                      ),
                      title: 'FFmpeg Binary',
                      subtitle: path.isEmpty
                          ? 'Optional, used by yt-dlp when needed'
                          : path,
                      icon: LucideIcons.settings2,
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                _buildGroupLabel(context, 'App'),
                const SizedBox(height: 16),
                _buildSettingItem(
                  context,
                  title: 'About YVD',
                  subtitle: 'Version $_version Premium',
                  icon: LucideIcons.info,
                ),
                const SizedBox(height: 12),
                _buildSettingItem(
                  context,
                  onTap: _manualUpdateCheck,
                  title: 'Check for Updates',
                  subtitle: 'Get the latest features and fixes',
                  icon: LucideIcons.refreshCw,
                ),

                const SizedBox(height: 60),
                Center(
                  child: Opacity(
                    opacity: 0.3,
                    child: Text(
                      'Made with ❤️ by HexaGhost',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 12,
                      ),
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
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        blur: 15,
        opacity: isDark ? 0.15 : 0.4,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.white),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 8,
          ),
          leading: Icon(
            icon,
            color: isDestructive ? Colors.red : const Color(0xFFFF0000),
            size: 24,
          ),
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
              color: (isDark ? Colors.white : const Color(0xFF1A1A1A))
                  .withOpacity(0.5),
              fontSize: 13,
            ),
          ),
          trailing:
              trailing ??
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
              ),
        ),
      ),
    );
  }
}
