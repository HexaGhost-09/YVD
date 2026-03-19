import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../globals.dart';
import '../services/tool_update_service.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ToolUpdateService _toolUpdateService = ToolUpdateService();
  String _version = '1.2.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _pickCustomFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      customPathNotifier.value = path;
    }
  }

  void _showBinaryUpdateDialog(ManagedBinary binary) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BinaryUpdateDialog(binary: binary, service: _toolUpdateService),
    );
  }

  Future<void> _manualUpdateCheck() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checking for updates...')));
    final update = await UpdateService().checkForUpdate();
    if (!mounted) return;
    if (update == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are on the latest version.')));
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
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Text('Settings', style: textTheme.displaySmall),
            const SizedBox(height: 8),
            Text('Version $_version', style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            
            _sectionHeader(context, 'Appearance', LucideIcons.palette),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: themeNotifier,
              builder: (context, theme, _) => _settingsCard(
                child: SwitchListTile(
                  secondary: Icon(LucideIcons.moon),
                  title: const Text('Dark mode'),
                  value: theme == ThemeMode.dark,
                  onChanged: (v) => themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            _sectionHeader(context, 'Storage', LucideIcons.folder),
            const SizedBox(height: 16),
            ValueListenableBuilder(
              valueListenable: customPathNotifier,
              builder: (context, path, _) => _settingsCard(
                child: ListTile(
                  leading: Icon(LucideIcons.hardDrive),
                  title: const Text('Custom Output Folder'),
                  subtitle: Text(path.isEmpty ? (Platform.isWindows ? 'Downloads' : 'Home') : path),
                  trailing: Icon(LucideIcons.edit),
                  onTap: _pickCustomFolder,
                ),
              ),
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: albumNotifier,
                builder: (context, album, _) => _settingsCard(
                  child: ListTile(
                    leading: Icon(LucideIcons.image),
                    title: const Text('Gallery Album Name'),
                    subtitle: Text(album),
                    trailing: Icon(LucideIcons.edit),
                    onTap: () => _showTextDialog('Album Name', 'e.g. YVD', albumNotifier),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),
            const SizedBox(height: 32),
            _sectionHeader(context, 'Core Binaries', LucideIcons.terminal),
            const SizedBox(height: 16),
            _binaryTile(context, ManagedBinary.ytDlp, LucideIcons.zap),
            const SizedBox(height: 12),
            _binaryTile(context, ManagedBinary.aria2c, LucideIcons.download),

            const SizedBox(height: 32),
            _sectionHeader(context, 'About', LucideIcons.info),
            const SizedBox(height: 16),
            _settingsCard(
              child: ListTile(
                leading: Icon(LucideIcons.refreshCw),
                title: const Text('Check for App Updates'),
                onTap: _manualUpdateCheck,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _binaryTile(BuildContext context, ManagedBinary binary, IconData icon) {
    final notifier = binary == ManagedBinary.ytDlp ? ytdlpPathNotifier : aria2cPathNotifier;
    final version = binary == ManagedBinary.ytDlp ? ytdlpVersionNotifier : aria2cVersionNotifier;
    
    final label = binary == ManagedBinary.ytDlp ? 'yt-dlp' : 'aria2c';
    final showInstall = binary == ManagedBinary.aria2c ? 'Extract' : 'Install';

    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, path, _) => ValueListenableBuilder(
        valueListenable: version,
        builder: (context, ver, _) => _settingsCard(
          child: ListTile(
            leading: Icon(icon),
            title: Text(label),
            subtitle: Text(path.isEmpty ? (binary == ManagedBinary.aria2c ? 'Needs extraction' : 'Not found') : (ver.isEmpty ? 'Installed' : ver)),
            trailing: FilledButton.tonal(
              onPressed: () => _showBinaryUpdateDialog(binary),
              child: Text(path.isEmpty ? (binary == ManagedBinary.aria2c ? 'Setup' : 'Install') : 'Update'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label, IconData icon) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2, color: color)),
      ],
    );
  }

  Widget _settingsCard({required Widget child}) => Card(clipBehavior: Clip.antiAlias, child: child);

  void _showTextDialog(String title, String hint, ValueNotifier<String> notifier) {
    final controller = TextEditingController(text: notifier.value);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () { notifier.value = controller.text.trim(); Navigator.pop(context); }, child: const Text('Save')),
        ],
      ),
    );
  }
}

class BinaryUpdateDialog extends StatefulWidget {
  final ManagedBinary binary;
  final ToolUpdateService service;
  const BinaryUpdateDialog({super.key, required this.binary, required this.service});

  @override
  State<BinaryUpdateDialog> createState() => _BinaryUpdateDialogState();
}

class _BinaryUpdateDialogState extends State<BinaryUpdateDialog> {
  BinaryUpdateInfo? _info;
  bool _isLoading = true;
  bool _isInstalling = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final info = await widget.service.checkUpdate(widget.binary);
      setState(() { _info = info; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _install() async {
    setState(() { _isInstalling = true; _progress = 0; });
    try {
      await widget.service.updateBinary(widget.binary, onProgress: (p) => setState(() => _progress = p));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _isInstalling = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Checking for updates...')]));
    if (_error != null) return AlertDialog(title: const Text('Error'), content: Text(_error!), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]);

    final info = _info!;
    final name = info.binary == ManagedBinary.ytDlp ? 'yt-dlp' : 'aria2c';
    final isAria = info.binary == ManagedBinary.aria2c;
    
    return AlertDialog(
      title: Text(isAria ? 'Setup aria2c' : 'Update $name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAria) 
            const Text('Aria2c is bundled with the application for high-speed multi-threaded downloads.')
          else ...[
            Text('Current: ${info.currentVersion}'),
            Text('Latest: ${info.latestVersion}'),
          ],
          if (_isInstalling) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: isAria ? null : _progress),
            const SizedBox(height: 8),
            Text(isAria ? 'Extracting...' : 'Downloading... ${(_progress * 100).toInt()}%'),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _isInstalling ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isInstalling || (!isAria && !info.updateAvailable) ? null : _install, 
          child: Text(isAria ? 'Extract Now' : 'Install Now')
        ),
      ],
    );
  }
}
