// Dev-only: renders the shared RouteMapView (used by booking_search,
// destination_guide, destination_detail) in both modes — two-point (pickup +
// destination + route) and single-point — with real resolved coordinates, to
// screenshot real tiles + markers. Not referenced by the shipped app.
//   flutter run -t lib/dev_map_screens_main.dart -d emulator-5554
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/theme/app_theme.dart';
import 'shared/widgets/common/route_map_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.darkTheme(baseTextTheme: GoogleFonts.montserratTextTheme()),
    home: Scaffold(
      appBar: AppBar(title: const Text('Map screens — RouteMapView')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Two-point LONG-DISTANCE (Tunis -> Tozeur): pickup + destination + route',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          RouteMapView.fromStrings(
            pickup: 'Tunis-Carthage Airport (TUN)',
            destination: 'Tozeur',
            height: 360,
          ),
          const SizedBox(height: 24),
          const Text('Single-point (Djerba): one marker',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const _SinglePoint(),
        ],
      ),
    ),
  ));
}

class _SinglePoint extends StatelessWidget {
  const _SinglePoint();
  @override
  Widget build(BuildContext context) =>
      RouteMapView.fromStrings(destination: 'Djerba', height: 260);
}
