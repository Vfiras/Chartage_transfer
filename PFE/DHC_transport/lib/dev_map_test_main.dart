// Dev-only: minimal Google Map to verify the API key renders real tiles on the
// emulator (not a gray box) before refactoring the real screens.
//   flutter run -t lib/dev_map_test_main.dart -d emulator-5554
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _MapTest(),
    ));

class _MapTest extends StatelessWidget {
  const _MapTest();

  @override
  Widget build(BuildContext context) {
    const tunis = LatLng(36.8065, 10.1815);
    return Scaffold(
      appBar: AppBar(title: const Text('Map key test')),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(target: tunis, zoom: 11),
        markers: {
          const Marker(markerId: MarkerId('tunis'), position: tunis),
        },
      ),
    );
  }
}
