import '../models/supplier_model.dart';
import 'transport_api_client.dart';

class SupplierService {
  const SupplierService();

  Future<List<SupplierModel>> listSuppliers() async {
    final response = await TransportApiClient.instance.get('/suppliers/');
    return (response['suppliers'] as List? ?? const [])
        .cast<Map>()
        .map((item) => SupplierModel.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<SupplierModel> updateStatus(String supplierId, String status) async {
    final response = await TransportApiClient.instance.patch(
      '/suppliers/$supplierId/status',
      {'status': status},
    );
    return SupplierModel.fromJson(
        (response['supplier'] as Map).cast<String, dynamic>());
  }

  Future<SupplierModel> updateSupplier(
    String supplierId,
    Map<String, dynamic> payload,
  ) async {
    final response = await TransportApiClient.instance
        .put('/suppliers/$supplierId', payload);
    return SupplierModel.fromJson(
        (response['supplier'] as Map).cast<String, dynamic>());
  }
}
