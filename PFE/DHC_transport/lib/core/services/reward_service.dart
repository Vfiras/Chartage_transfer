import 'transport_api_client.dart';

class RewardService {
  const RewardService();

  Future<Map<String, dynamic>> getRewardsMe() {
    return TransportApiClient.instance.get('/rewards/me');
  }

  Future<Map<String, dynamic>> getAvailablePromos() {
    return TransportApiClient.instance.get('/rewards/available-promos');
  }
}
