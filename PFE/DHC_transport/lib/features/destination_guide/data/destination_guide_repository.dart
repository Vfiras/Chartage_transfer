import '../domain/destination_recommendation.dart';
import '../../../core/services/transport_api_client.dart';

class DestinationGuideRepository {
  const DestinationGuideRepository();

  Future<List<DestinationRecommendation>> fetchAll({
    String? city,
    RecommendationCategory? category,
  }) async {
    final response = await TransportApiClient.instance.get(
      '/recommendations/',
      query: {
        if (city != null && city.isNotEmpty) 'city': city,
        if (category != null) 'category': category.name,
      },
    );
    final items = (response['items'] as List? ?? const [])
        .cast<Map>()
        .map((item) =>
            DestinationRecommendation.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
    return items.isEmpty ? all() : items;
  }

  List<DestinationRecommendation> featured() {
    return _items.where((item) => item.featured).toList(growable: false);
  }

  List<DestinationRecommendation> all() => List.unmodifiable(_items);

  List<DestinationRecommendation> byCategory(RecommendationCategory category) {
    return _items
        .where((item) => item.category == category)
        .toList(growable: false);
  }

  List<DestinationRecommendation> forDestination(String destination) {
    final needle = destination.toLowerCase();
    return _items.where((item) {
      final haystack = '${item.city} ${item.region} ${item.name}'.toLowerCase();
      return haystack.contains(needle);
    }).toList(growable: false);
  }

  static const _items = [
    DestinationRecommendation(
      id: 'rec-1',
      category: RecommendationCategory.restaurant,
      name: 'Cafe de la Plage',
      city: 'Bizerte',
      region: 'Ras Jbal',
      imageUrl:
          'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80',
      rating: 4.6,
      priceRange: '\$\$',
      tags: ['Sea View', 'Breakfast', 'Coffee'],
      description:
          'Relaxed seaside breakfast and lunch spot with a tourist-friendly menu and fast service.',
      notes:
          'Great for guests arriving early. Quiet terrace, English menu, card payment accepted.',
      phone: '+216 20 123 456',
      openingHours: 'Open 07:00 - 22:00',
      primaryLabel: 'Food Type',
      primaryValue: 'Seafood & Cafe',
      secondaryLabel: 'View',
      secondaryValue: 'Sea View',
      tertiaryLabel: 'Specialty',
      tertiaryValue: 'Breakfast plates',
      featured: true,
    ),
    DestinationRecommendation(
      id: 'rec-2',
      category: RecommendationCategory.hotel,
      name: 'Dar Zmen Boutique Hotel',
      city: 'Bizerte',
      region: 'Ras Jbal',
      imageUrl:
          'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80',
      rating: 4.4,
      priceRange: '\$\$\$',
      tags: ['Family', 'Business', 'Parking'],
      description:
          'Boutique stay with clean service, premium rooms, and easy access for transfer guests.',
      notes:
          'Recommended for families and business guests. Ask for late check-in when needed.',
      phone: '+216 21 555 111',
      openingHours: '24/7 Reception',
      primaryLabel: 'Stars',
      primaryValue: '4-Star',
      secondaryLabel: 'Amenities',
      secondaryValue: 'Wi-Fi, Parking',
      tertiaryLabel: 'Audience',
      tertiaryValue: 'Family / Business',
      featured: true,
    ),
    DestinationRecommendation(
      id: 'rec-3',
      category: RecommendationCategory.cafe,
      name: 'The Blue Coffee',
      city: 'Bizerte',
      region: 'Ras Jbal',
      imageUrl:
          'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=1200&q=80',
      rating: 4.3,
      priceRange: '\$',
      tags: ['Desserts', 'Quiet', 'Coffee'],
      description:
          'A calm coffee stop with panoramic views and a comfortable atmosphere for couples.',
      notes:
          'Ideal for short breaks after airport transfers or before a city tour.',
      phone: '+216 28 901 234',
      openingHours: '08:00 - 23:00',
      primaryLabel: 'Type',
      primaryValue: 'Specialty Cafe',
      secondaryLabel: 'View',
      secondaryValue: 'City / Sea',
      tertiaryLabel: 'Best for',
      tertiaryValue: 'Coffee & desserts',
    ),
    DestinationRecommendation(
      id: 'rec-4',
      category: RecommendationCategory.activity,
      name: 'Cap Blanc Sunset Walk',
      city: 'Bizerte',
      region: 'Cap Blanc',
      imageUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      rating: 4.8,
      priceRange: 'Free',
      tags: ['Nature', 'Family', 'Sunset'],
      description:
          'Short scenic walk with excellent sunset views and photo opportunities.',
      notes:
          'Recommend for tourists who want a simple activity after a long drive.',
      phone: '+216 22 000 450',
      openingHours: 'Best at 17:00 - 20:00',
      primaryLabel: 'Activity',
      primaryValue: 'Scenic walk',
      secondaryLabel: 'Duration',
      secondaryValue: '1 - 2 hours',
      tertiaryLabel: 'Audience',
      tertiaryValue: 'Family / Couples',
      featured: true,
    ),
    DestinationRecommendation(
      id: 'rec-5',
      category: RecommendationCategory.restaurant,
      name: 'Dar El Jeld Restaurant',
      city: 'Tunis',
      region: 'Medina',
      imageUrl:
          'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=1200&q=80',
      rating: 4.9,
      priceRange: '\$\$\$',
      tags: ['Fine Dining', 'Historic', 'Local Cuisine'],
      description:
          'Premium Tunisian dining experience for tourists looking for a memorable dinner.',
      notes: 'Best recommended for premium guests and evening city trips.',
      phone: '+216 70 010 010',
      openingHours: '12:00 - 23:30',
      primaryLabel: 'Food Type',
      primaryValue: 'Traditional Tunisian',
      secondaryLabel: 'View',
      secondaryValue: 'Historic courtyard',
      tertiaryLabel: 'Specialty',
      tertiaryValue: 'Lamb & couscous',
    ),
    DestinationRecommendation(
      id: 'rec-6',
      category: RecommendationCategory.hotel,
      name: 'La Badira Hammamet',
      city: 'Hammamet',
      region: 'Yasmine',
      imageUrl:
          'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=80',
      rating: 4.7,
      priceRange: '\$\$\$\$',
      tags: ['Luxury', 'Beach', 'Couples'],
      description:
          'Luxury beachfront stay with premium service and elegant interiors.',
      notes:
          'Strong recommendation for couples and VIP guests heading to the coast.',
      phone: '+216 72 123 000',
      openingHours: '24/7 Reception',
      primaryLabel: 'Stars',
      primaryValue: '5-Star',
      secondaryLabel: 'Amenities',
      secondaryValue: 'Spa, Pool, Beach',
      tertiaryLabel: 'Audience',
      tertiaryValue: 'Couples / VIP',
    ),
  ];
}
