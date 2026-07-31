// Dev-only entrypoint to preview AVA's chat cards in isolation.
//   flutter run -t lib/dev_preview_main.dart -d emulator-5554
// Not referenced by the shipped app (which uses lib/main.dart).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'screens/assistant/dev/ava_cards_preview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final base = GoogleFonts.montserratTextTheme();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.darkTheme(baseTextTheme: base),
    home: const AvaCardsPreviewScreen(),
  ));
}
