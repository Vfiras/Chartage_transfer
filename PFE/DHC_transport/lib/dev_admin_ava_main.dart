// Dev-only entrypoint: logs in as the seeded admin, then opens
// AdminAssistantScreen and auto-sends a fleet-list prompt so an automated
// screenshot can capture a REAL admin confirmation card (Flutter login+nav isn't
// reliably adb-automatable). Not referenced by the shipped app.
//   flutter run -t lib/dev_admin_ava_main.dart -d emulator-5554
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/assistant/admin_assistant_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.darkTheme(baseTextTheme: GoogleFonts.montserratTextTheme()),
    home: const _Boot(),
  ));
}

class _Boot extends StatefulWidget {
  const _Boot();
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  String _status = 'Logging in as admin…';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _login();
  }

  Future<void> _login() async {
    try {
      await AuthService.instance.login(
        identifier: 'admin@carthage-transfer.tn',
        password: 'admin123',
      );
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _status = 'Login failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return const AdminAssistantScreen(
        autoSend: 'Show me the current fleet list',
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Center(
        child: Text(_status, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
