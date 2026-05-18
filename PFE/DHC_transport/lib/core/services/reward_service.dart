import 'transport_api_client.dart';

class RewardService {
  const RewardService();

  Future<Map<String, dynamic>> getRewards() {
    return TransportApiClient.instance.get('/rewards/');
  }
}
