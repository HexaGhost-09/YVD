import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const YVDApp());
}

class YVDApp extends StatelessWidget {
  const YVDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YVD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFF0000), // YouTube Red
        useMaterial3: true,
        fontFamily: GoogleFonts.inter().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF0000),
          brightness: Brightness.dark,
          secondary: const Color(0xFF2196F3), // Blue
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
