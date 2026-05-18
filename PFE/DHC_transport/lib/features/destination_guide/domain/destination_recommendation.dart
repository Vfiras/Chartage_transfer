enum RecommendationCategory {
  restaurant,
  hotel,
  cafe,
  activity,
  attraction,
}

extension RecommendationCategoryX on RecommendationCategory {
  String get label => switch (this) {
        RecommendationCategory.restaurant => 'Restaurant',
        RecommendationCategory.hotel => 'Hotel',
        RecommendationCategory.cafe => 'Cafe',
        RecommendationCategory.activity => 'Activity',
        RecommendationCategory.attraction => 'Attraction',
      };

  String get shortLabel => switch (this) {
        RecommendationCategory.restaurant => 'Food',
        RecommendationCategory.hotel => 'Stay',
        RecommendationCategory.cafe => 'Cafe',
        RecommendationCategory.activity => 'Activity',
        RecommendationCategory.attraction => 'Sight',
      };
}

class DestinationRecommendation {
  final String id;
  final RecommendationCategory category;
  final String name;
  final String city;
  final String region;
  final String imageUrl;
  final double rating;
  final String priceRange;
  final List<String> tags;
  final String description;
  final String notes;
  final String phone;
  final String openingHours;
  final String primaryLabel;
  final String primaryValue;
  final String secondaryLabel;
  final String secondaryValue;
  final String tertiaryLabel;
  final String tertiaryValue;
  final bool featured;
  final bool visible;

  const DestinationRecommendation({
    required this.id,
    required this.category,
    required this.name,
    required this.city,
    required this.region,
    required this.imageUrl,
    required this.rating,
    required this.priceRange,
    required this.tags,
    required this.description,
    required this.notes,
    required this.phone,
    required this.openingHours,
    required this.primaryLabel,
    required this.primaryValue,
    required this.secondaryLabel,
    required this.secondaryValue,
    required this.tertiaryLabel,
    required this.tertiaryValue,
    this.featured = false,
    this.visible = true,
  });

  factory DestinationRecommendation.fromJson(Map<String, dynamic> json) {
    final categoryText =
        json['category']?.toString().toLowerCase() ?? 'attraction';
    final category = RecommendationCategory.values.firstWhere(
      (item) => item.name == categoryText,
      orElse: () => RecommendationCategory.attraction,
    );
    final tags =
        (json['tags'] as List?)?.map((item) => item.toString()).toList() ??
            <String>[];
    return DestinationRecommendation(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      category: category,
      name: json['name']?.toString() ?? 'Guide item',
      city: json['city']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ??
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      priceRange: json['price_range']?.toString() ?? '',
      tags: tags,
      description: json['description']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      openingHours: json['opening_hours']?.toString() ?? '',
      primaryLabel: json['primary_label']?.toString() ?? 'Category',
      primaryValue: json['primary_value']?.toString() ?? category.label,
      secondaryLabel: json['secondary_label']?.toString() ?? 'City',
      secondaryValue: json['secondary_value']?.toString() ??
          (json['city']?.toString() ?? ''),
      tertiaryLabel: json['tertiary_label']?.toString() ?? 'Region',
      tertiaryValue: json['tertiary_value']?.toString() ??
          (json['region']?.toString() ?? ''),
      featured: json['featured'] == true,
      visible: json['visible'] != false,
    );
  }
}
