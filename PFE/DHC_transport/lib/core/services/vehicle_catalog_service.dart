import '../../data/home_data.dart';
import '../../models/vehicle.dart';
import 'transport_api_client.dart';

class VehicleCatalogService {
  const VehicleCatalogService();

  Future<List<Vehicle>> listVehicles() async {
    try {
      final response = await TransportApiClient.instance.get('/cars/');
      final items = (response['cars'] as List? ?? const [])
          .cast<Map>()
          .toList(growable: false);
      if (items.isEmpty) return HomeData.vehicles;
      return [
        for (var index = 0; index < items.length; index++)
          Vehicle.fromJson(items[index].cast<String, dynamic>(), index + 1),
      ];
    } catch (_) {
      return HomeData.vehicles;
    }
  }
}
