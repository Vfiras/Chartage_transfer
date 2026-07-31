import '../models/transport_trip.dart';
import 'transport_api_client.dart';

class TripService {
  const TripService();

  Future<List<TransportTrip>> listTrips({String? status}) async {
    final response =
        await TransportApiClient.instance.get('/bookings/', query: {
      if (status != null) 'booking_status': status,
    });
    return (response['bookings'] as List? ?? const [])
        .cast<Map>()
        .map((item) => TransportTrip.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<Map<String, List<TransportTrip>>> history() async {
    final response = await TransportApiClient.instance.get('/bookings/history');
    List<TransportTrip> parse(String key) {
      return (response[key] as List? ?? const [])
          .cast<Map>()
          .map((item) => TransportTrip.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false);
    }

    return {'upcoming': parse('upcoming'), 'past': parse('past')};
  }

  Future<TransportTrip> createBooking(Map<String, dynamic> payload) async {
    final response =
        await TransportApiClient.instance.post('/bookings/', payload);
    return TransportTrip.fromJson(
        (response['booking'] as Map).cast<String, dynamic>());
  }

  Future<TransportTrip> updateStatus(String bookingId, String status) async {
    final response = await TransportApiClient.instance.patch(
      '/bookings/$bookingId/status',
      {'status': status},
    );
    return TransportTrip.fromJson(
        (response['booking'] as Map).cast<String, dynamic>());
  }

  Future<TransportTrip> cancelBooking(String bookingId) async {
    final response = await TransportApiClient.instance.patch(
      '/bookings/$bookingId/cancel',
      {},
    );
    return TransportTrip.fromJson(
        (response['booking'] as Map).cast<String, dynamic>());
  }

  Future<TransportTrip> updateTrip(
    String bookingId,
    Map<String, dynamic> payload,
  ) async {
    final response = await TransportApiClient.instance.put(
      '/bookings/$bookingId',
      payload,
    );
    return TransportTrip.fromJson(
        (response['booking'] as Map).cast<String, dynamic>());
  }

  Future<void> deleteBooking(String bookingId) async {
    await TransportApiClient.instance.delete('/bookings/$bookingId');
  }

  /// Admin: approve a cash booking's payment — confirms the booking and
  /// notifies the client (PATCH /admin/bookings/{id}/approve-payment).
  Future<TransportTrip> approvePayment(String bookingId) async {
    final response = await TransportApiClient.instance.patch(
      '/admin/bookings/$bookingId/approve-payment',
      {},
    );
    return TransportTrip.fromJson(
        (response['booking'] as Map).cast<String, dynamic>());
  }
}
