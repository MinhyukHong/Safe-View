import 'package:flutter/material.dart';
import 'url_entry_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const SafeViewApp());
}

class SafeViewApp extends StatelessWidget {
  const SafeViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe-View',
      theme: ThemeData.dark().copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: const UrlEntryScreen(),
    );
  }
}