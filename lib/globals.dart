import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> albumNotifier = ValueNotifier("YVD");
final ValueNotifier<String> ytdlpPathNotifier = ValueNotifier('');
final ValueNotifier<String> ffmpegPathNotifier = ValueNotifier('');

class PrefService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Load Theme
    final savedTheme = _prefs.getString('themeMode') ?? 'light';
    themeNotifier.value = savedTheme == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    themeNotifier.addListener(() {
      _prefs.setString(
        'themeMode',
        themeNotifier.value == ThemeMode.dark ? 'dark' : 'light',
      );
    });

    // Load Album/Path
    albumNotifier.value = _prefs.getString('albumName') ?? 'YVD';
    albumNotifier.addListener(() {
      _prefs.setString('albumName', albumNotifier.value);
    });

    ytdlpPathNotifier.value = _prefs.getString('ytdlpPath') ?? '';
    ytdlpPathNotifier.addListener(() {
      _prefs.setString('ytdlpPath', ytdlpPathNotifier.value);
    });

    ffmpegPathNotifier.value = _prefs.getString('ffmpegPath') ?? '';
    ffmpegPathNotifier.addListener(() {
      _prefs.setString('ffmpegPath', ffmpegPathNotifier.value);
    });
  }
}
