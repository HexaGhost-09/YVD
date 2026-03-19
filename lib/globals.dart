import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> albumNotifier = ValueNotifier("YVD");
final ValueNotifier<String> customPathNotifier = ValueNotifier('');
final ValueNotifier<String> ytdlpPathNotifier = ValueNotifier('');
final ValueNotifier<String> ffmpegPathNotifier = ValueNotifier('');
final ValueNotifier<String> aria2cPathNotifier = ValueNotifier('');
final ValueNotifier<String> ytdlpVersionNotifier = ValueNotifier('');
final ValueNotifier<String> ffmpegVersionNotifier = ValueNotifier('');
final ValueNotifier<String> aria2cVersionNotifier = ValueNotifier('');

class PrefService {
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    themeNotifier.value = (_prefs.getString('themeMode') ?? 'light') == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    themeNotifier.addListener(() {
      _prefs.setString('themeMode', themeNotifier.value == ThemeMode.dark ? 'dark' : 'light');
    });

    albumNotifier.value = _prefs.getString('albumName') ?? 'YVD';
    albumNotifier.addListener(() {
      _prefs.setString('albumName', albumNotifier.value);
    });

    customPathNotifier.value = _prefs.getString('customPath') ?? '';
    customPathNotifier.addListener(() {
      _prefs.setString('customPath', customPathNotifier.value);
    });

    ytdlpPathNotifier.value = _prefs.getString('ytdlpPath') ?? '';
    ytdlpPathNotifier.addListener(() {
      _prefs.setString('ytdlpPath', ytdlpPathNotifier.value);
    });

    ffmpegPathNotifier.value = _prefs.getString('ffmpegPath') ?? '';
    ffmpegPathNotifier.addListener(() {
      _prefs.setString('ffmpegPath', ffmpegPathNotifier.value);
    });

    aria2cPathNotifier.value = _prefs.getString('aria2cPath') ?? '';
    aria2cPathNotifier.addListener(() {
      _prefs.setString('aria2cPath', aria2cPathNotifier.value);
    });

    ytdlpVersionNotifier.value = _prefs.getString('ytdlpVersion') ?? '';
    ytdlpVersionNotifier.addListener(() {
      _prefs.setString('ytdlpVersion', ytdlpVersionNotifier.value);
    });

    ffmpegVersionNotifier.value = _prefs.getString('ffmpegVersion') ?? '';
    ffmpegVersionNotifier.addListener(() {
      _prefs.setString('ffmpegVersion', ffmpegVersionNotifier.value);
    });

    aria2cVersionNotifier.value = _prefs.getString('aria2cVersion') ?? '';
    aria2cVersionNotifier.addListener(() {
      _prefs.setString('aria2cVersion', aria2cVersionNotifier.value);
    });
  }
}
