import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  final String description;
  final String placeId;
  const PlaceSuggestion({required this.description, required this.placeId});
}

class PlacesService {
  static const _base = 'https://maps.googleapis.com/maps/api/place';
  final String _key;
  const PlacesService(this._key);

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (input.trim().length < 2) return [];
    try {
      final uri = Uri.parse('$_base/autocomplete/json').replace(
        queryParameters: {
          'input': input.trim(),
          'components': 'country:tn',
          'language': 'en',
          'key': _key,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return [];
      final data = json.decode(res.body) as Map<String, dynamic>;
      final predictions = data['predictions'] as List? ?? [];
      return predictions
          .map((p) => PlaceSuggestion(
                description: p['description']?.toString() ?? '',
                placeId: p['place_id']?.toString() ?? '',
              ))
          .where((s) => s.description.isNotEmpty && s.placeId.isNotEmpty)
          .take(5)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<LatLng?> getCoordinates(String placeId) async {
    try {
      final uri = Uri.parse('$_base/details/json').replace(
        queryParameters: {
          'place_id': placeId,
          'fields': 'geometry',
          'key': _key,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body) as Map<String, dynamic>;
      final loc = data['result']?['geometry']?['location'];
      if (loc == null) return null;
      return LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
