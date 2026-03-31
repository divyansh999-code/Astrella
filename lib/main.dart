import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'engine_console_screen.dart';

void main() {
  runApp(const AstrellaApp());
}

class AstrellaApp extends StatelessWidget {
  const AstrellaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Astrella',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xff000000),
        textTheme: GoogleFonts.spaceMonoTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: const Color(0xffF5F5F0),
          displayColor: const Color(0xffF5F5F0),
        ),
      ),
      home: const EngineConsoleScreen(),
    );
  }
}