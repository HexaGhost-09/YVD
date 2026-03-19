import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../globals.dart';
import '../services/tool_update_service.dart';
import '../services/update_service.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ToolUpdateService _toolUpdateService = ToolUpdateService();
  String _version = '1.1.3';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  void _showTextDialog({
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
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
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

  Future<void> _manualUpdateCheck() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking for updates...')),
    );
    final update = await UpdateService().checkForUpdate();
    if (!mounted) return;
    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are on the latest version.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update ${update.tagName} available'),
        content: Text(update.body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
          FilledButton(
            onPressed: () {
              launchUrl(Uri.parse(update.htmlUrl), mode: LaunchMode.externalApplication);
              Navigator.pop(context);
            },
            child: const Text('Get Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supportsDesktopBinaries =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Text('Settings', style: textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Customize your experience and manage binaries.',
              style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            _sectionHeader(context, 'Appearance', LucideIcons.palette),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: themeNotifier,
              builder: (context, theme, _) => _settingsCard(
                child: SwitchListTile(
                  secondary: Icon(LucideIcons.moon),
                  title: const Text('Dark mode'),
                  subtitle: const Text('Switch between light and dark themes'),
                  value: theme == ThemeMode.dark,
                  onChanged: (value) {
                    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            _sectionHeader(context, 'Downloads', LucideIcons.downloadCloud),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: albumNotifier,
              builder: (context, album, _) => _settingsCard(
                child: ListTile(
                  leading: Icon(LucideIcons.folder),
                  title: const Text('Storage Path'),
                  subtitle: Text('/Gallery/$album'),
                  trailing: Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => _showTextDialog(
                    title: 'Download Folder',
                    hint: 'e.g. YVD Downloads',
                    notifier: albumNotifier,
                  ),
                ),
              ),
            ),
            if (supportsDesktopBinaries) ...[
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: ytdlpPathNotifier,
                builder: (context, path, _) => _settingsCard(
                  child: ListTile(
                    leading: Icon(LucideIcons.terminal),
                    title: const Text('yt-dlp Binary'),
                    subtitle: Text(path.isEmpty ? 'Use internal' : path),
                    trailing: Icon(LucideIcons.edit3, size: 18),
                    onTap: () => _showTextDialog(
                      title: 'yt-dlp Path',
                      hint: r'C:\Tools\yt-dlp.exe',
                      notifier: ytdlpPathNotifier,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: ffmpegPathNotifier,
                builder: (context, path, _) => _settingsCard(
                  child: ListTile(
                    leading: Icon(LucideIcons.video),
                    title: const Text('FFmpeg Binary'),
                    subtitle: Text(path.isEmpty ? 'Optional' : path),
                    trailing: Icon(LucideIcons.edit3, size: 18),
                    onTap: () => _showTextDialog(
                      title: 'FFmpeg Path',
                      hint: r'C:\Tools\ffmpeg.exe',
                      notifier: ffmpegPathNotifier,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            _sectionHeader(context, 'About', LucideIcons.info),
            const SizedBox(height: 16),
            _settingsCard(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(LucideIcons.fingerprint),
                    title: const Text('Software Version'),
                    subtitle: Text('v$_version'),
                  ),
                  const Divider(indent: 70, endIndent: 20, height: 1),
                  ListTile(
                    leading: Icon(LucideIcons.refreshCw),
                    title: const Text('Check for Updates'),
                    onTap: _manualUpdateCheck,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 12),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 13,
            color: scheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _settingsCard({required Widget child}) {
    return Card(clipBehavior: Clip.antiAlias, child: child);
  }
}
