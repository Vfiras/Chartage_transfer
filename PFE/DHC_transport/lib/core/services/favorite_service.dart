import '../models/favorite_location.dart';
import 'auth_service.dart';
import 'transport_api_client.dart';

class FavoriteService {
  const FavoriteService();

  static const defaults = [
    FavoriteLocation(
      id: 'home',
      label: 'La Marsa Residence',
      address: '2 Rue des Jasmins, La Marsa 2078',
      type: 'home',
    ),
    FavoriteLocation(
      id: 'work',
      label: 'Tunis Business Centre',
      address: 'Avenue Habib Bourguiba, Tunis 1000',
      type: 'work',
    ),
    FavoriteLocation(
      id: 'airport',
      label: 'Tunis-Carthage Airport',
      address: 'Route de l\'Aéroport, Ariana 2035',
      type: 'airport',
    ),
    FavoriteLocation(
      id: 'hammamet',
      label: 'Hôtel Les Orangers',
      address: 'Avenue Habib Thameur, Hammamet 8050',
      type: 'hotel',
    ),
  ];

  Future<List<FavoriteLocation>> listFavorites() async {
    if (!AuthService.instance.isAuthenticated) return defaults;
    try {
      final response = await TransportApiClient.instance.get('/favorites/');
      final items = (response['favorites'] as List? ?? const [])
          .cast<Map>()
          .map(
              (item) => FavoriteLocation.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
      if (items.isEmpty) return defaults;
      // Merge: real saved items first, then any default whose type isn't
      // already represented by a saved item (avoids duplicating Home / Work etc.)
      final savedTypes = items.map((e) => e.type).toSet();
      final missingDefaults =
          defaults.where((d) => !savedTypes.contains(d.type)).toList();
      return [...items, ...missingDefaults];
    } catch (_) {
      return defaults;
    }
  }

  Future<FavoriteLocation> addFavorite({
    required String label,
    required String address,
    required String type,
  }) async {
    final response = await TransportApiClient.instance.post('/favorites/', {
      'label': label,
      'address': address,
      'type': type,
    });
    return FavoriteLocation.fromJson(
      (response['favorite'] as Map).cast<String, dynamic>(),
    );
  }

  Future<void> deleteFavorite(String id) async {
    if (defaults.any((item) => item.id == id)) return;
    await TransportApiClient.instance.delete('/favorites/$id');
  }
}
