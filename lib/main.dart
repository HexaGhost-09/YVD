import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/navigation_screen.dart';
import 'globals.dart';

void main() {
  runApp(const YVDApp());
}

class YVDApp extends StatelessWidget {
  const YVDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'YVD',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFFFF0000),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
            fontFamily: GoogleFonts.inter().fontFamily,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF0000),
              brightness: Brightness.light,
              secondary: const Color(0xFF2196F3),
              surface: Colors.white,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFFFF0000),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF0F0F0F),
            fontFamily: GoogleFonts.inter().fontFamily,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF0000),
              brightness: Brightness.dark,
              secondary: const Color(0xFF2196F3),
              surface: const Color(0xFF1A1A1A),
            ),
          ),
          home: const NavigationScreen(),
        );
      },
    );
  }
}
