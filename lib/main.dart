import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';
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
      title: 'Carthage',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(
        baseTextTheme: GoogleFonts.comfortaaTextTheme(),
      ),
      home: const LoginScreen(),
    );
  }
}
