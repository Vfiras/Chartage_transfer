// Dev-only entrypoint: logs in as the seeded client and opens the vehicle
// selection screen directly with TUN → Hammamet coordinates pre-filled, so an
// automated screenshot can confirm REAL EUR quotes render on the fleet cards
// (regression guard for the backendId join bug). Not referenced by the app.
//   flutter run -t lib/dev_fleet_main.dart -d emulator-5554
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/services/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'models/booking_data.dart';
import 'screens/booking_fleet_screen.dart';

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

  BookingData get _data => BookingData(
        pickup: 'Tunis-Carthage Airport (TUN)',
        destination: 'Hammamet',
        tripType: 'one-way',
        departureDate: '2026-09-15',
        departureTime: '10:00 AM',
        passengers: 2,
        luggageCount: 2,
        // Coordinates the search screen would have resolved — drives the real
        // POST /bookings/price-estimate batch quote.
        pickupLat: 36.851033,
        pickupLng: 10.227217,
        destinationLat: 36.400556,
        destinationLng: 10.616944,
      );

  @override
  Widget build(BuildContext context) {
    if (_ready) return BookingFleetScreen(data: _data);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Center(
        child: Text(_status, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
