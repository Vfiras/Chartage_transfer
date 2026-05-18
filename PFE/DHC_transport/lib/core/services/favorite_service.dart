import '../models/favorite_location.dart';
import 'auth_service.dart';
import 'transport_api_client.dart';

class FavoriteService {
  const FavoriteService();

  static const defaults = [
    FavoriteLocation(
      id: 'home',
      label: 'Home',
      address: 'La Marsa, Tunis',
      type: 'home',
    ),
    FavoriteLocation(
      id: 'work',
      label: 'Work',
      address: 'Tunis Centre',
      type: 'work',
    ),
    FavoriteLocation(
      id: 'airport',
      label: 'Airport',
      address: 'Tunis-Carthage Airport',
      type: 'airport',
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
      return items.isEmpty ? defaults : items;
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
