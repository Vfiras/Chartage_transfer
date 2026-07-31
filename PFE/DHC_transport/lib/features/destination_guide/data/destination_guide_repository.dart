import '../domain/destination_recommendation.dart';
import '../../../core/services/transport_api_client.dart';

class DestinationGuideRepository {
  const DestinationGuideRepository();

  Future<List<DestinationRecommendation>> fetchAll({
    String? city,
    RecommendationCategory? category,
  }) async {
    final response = await TransportApiClient.instance.get(
      '/destinations/recommendations/',
      query: {
        if (city != null && city.isNotEmpty) 'city': city,
        if (category != null) 'category': category.name,
      },
    );
    return (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((item) =>
            DestinationRecommendation.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }
}
