import 'transport_api_client.dart';

class NotificationService {
  const NotificationService();

  Future<List<Map<String, dynamic>>> listNotifications() async {
    final response = await TransportApiClient.instance.get('/notifications/');
    return (response['notifications'] as List? ?? const [])
        .cast<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<void> markAsRead(String notificationId) async {
    await TransportApiClient.instance.patch(
      '/notifications/$notificationId/read',
      {},
    );
  }

  Future<void> markAllRead() async {
    await TransportApiClient.instance.patch('/notifications/read-all', {});
  }
}
