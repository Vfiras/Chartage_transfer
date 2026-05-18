import 'transport_api_client.dart';

class AssistantService {
  const AssistantService();

  Future<String> sendMessage(String message) async {
    final response = await TransportApiClient.instance.post('/assistant/chat', {
      'message': message,
    });
    return response['reply']?.toString() ?? 'I can help with your trip.';
  }
}
