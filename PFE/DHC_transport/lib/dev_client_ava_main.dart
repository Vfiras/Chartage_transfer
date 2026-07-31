// Dev-only entrypoint: logs in as the seeded client, then opens the AVA
// concierge screen directly so automated screenshots can capture its three
// states (lounge / first exchange / longer conversation). Not referenced by
// the shipped app.
//   flutter run -t lib/dev_client_ava_main.dart -d emulator-5554
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/assistant_screen.dart';

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
  String _status = 'Logging in as client…';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _login();
  }

  Future<void> _login() async {
    try {
      await AuthService.instance.login(
        identifier: 'client@example.com',
        password: 'client123',
      );
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _status = 'Login failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const AssistantScreen();
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Center(
        child: Text(_status, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
