import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class DirectionsService {
  static const _base =
      'https://maps.googleapis.com/maps/api/directions/json';
  final String _key;
  const DirectionsService(this._key);

  /// Returns the driving route as a list of [LatLng] points decoded from the
  /// Directions API overview polyline. Returns empty on any error or when no
  /// route exists between the two points (silent fail — callers show no
  /// polyline rather than falling back to the straight dashed line).
  Future<List<LatLng>> getRoute(LatLng origin, LatLng dest) async {
    try {
      final uri = Uri.parse(_base).replace(queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${dest.latitude},${dest.longitude}',
        'mode': 'driving',
        'key': _key,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final data = json.decode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List? ?? [];
      if (routes.isEmpty) return [];
      final encoded =
          routes[0]['overview_polyline']?['points'] as String? ?? '';
      if (encoded.isEmpty) return [];
      return _decode(encoded);
    } catch (_) {
      return [];
    }
  }

  /// Standard Google polyline decoding algorithm (~15 lines).
  static List<LatLng> _decode(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int shift = 0, result = 0, b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
