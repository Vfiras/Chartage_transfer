import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Curated coordinates for the Tunisian places this app actually deals with.
///
/// The booking/destination data stores address/city STRINGS only (no lat/lng in
/// the models or backend). Rather than silently geocoding with an unverified
/// method, this resolves the known set of places to real coordinates by
/// case-insensitive substring match. Unknown strings return null (caller centers
/// on the country and shows no marker, instead of inventing a location).
class TnLocations {
  TnLocations._();

  /// Sensible default camera target when nothing resolves (country centre).
  static const LatLng tunisiaCenter = LatLng(34.0, 9.6);

  /// Ordered longest-key-first so "tunis airport" wins over "tunis".
  static const Map<String, LatLng> _places = {
    'tunis-carthage airport': LatLng(36.851, 10.227),
    'tunis carthage airport': LatLng(36.851, 10.227),
    'carthage airport': LatLng(36.851, 10.227),
    'tunis airport': LatLng(36.851, 10.227),
    'monastir airport': LatLng(35.758, 10.754),
    'enfidha airport': LatLng(36.075, 10.438),
    'djerba airport': LatLng(33.875, 10.775),
    'djerba-zarzis': LatLng(33.875, 10.775),
    'tunis city centre': LatLng(36.8065, 10.1815),
    'tunis city center': LatLng(36.8065, 10.1815),
    'sidi bou said': LatLng(36.871, 10.347),
    'la marsa': LatLng(36.878, 10.324),
    'la goulette': LatLng(36.818, 10.305),
    'hammamet': LatLng(36.400, 10.616),
    'nabeul': LatLng(36.451, 10.735),
    'sousse': LatLng(35.825, 10.636),
    'monastir': LatLng(35.778, 10.826),
    'enfidha': LatLng(36.075, 10.438),
    'kairouan': LatLng(35.678, 10.096),
    'sfax': LatLng(34.740, 10.760),
    'bizerte': LatLng(37.274, 9.873),
    'gammarth': LatLng(36.920, 10.290),
    'tozeur': LatLng(33.919, 8.133),
    'djerba': LatLng(33.807, 10.845),
    'carthage': LatLng(36.858, 10.331),
    'ariana': LatLng(36.862, 10.193),
    'tunis': LatLng(36.8065, 10.1815),
  };

  /// Resolve a free-text place string to coordinates, or null if not recognised.
  static LatLng? resolve(String? raw) {
    if (raw == null) return null;
    final s = raw.toLowerCase().trim();
    if (s.isEmpty) return null;
    // Keys are declared longest/most-specific first; first contains-match wins.
    for (final entry in _places.entries) {
      if (s.contains(entry.key)) return entry.value;
    }
    return null;
  }
}
