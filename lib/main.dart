import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/app_shell.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LuxuryAirportTransferApp());
}

class LuxuryAirportTransferApp extends StatelessWidget {
  const LuxuryAirportTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luxury Airport Transfer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(
        baseTextTheme: GoogleFonts.interTextTheme(),
      ),
      home: const AppShell(),
    );
  }
}
