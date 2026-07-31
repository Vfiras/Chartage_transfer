class Vehicle {
  final int id;
  final String backendId; // Mongo _id (e.g. "car-comfort-sedan") for API calls
  final String name;
  final String model;
  final String capacity;
  final int bags;
  final String label;
  final bool labelGold;
  final int price;
  final String image;
  final int seats;
  final String category;
  final bool available;

  const Vehicle({
    required this.id,
    this.backendId = '',
    required this.name,
    required this.model,
    required this.capacity,
    required this.bags,
    required this.label,
    required this.labelGold,
    required this.price,
    required this.image,
    this.seats = 0,
    this.category = '',
    this.available = true,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json, int fallbackId) {
    final name = json['name']?.toString() ?? 'Premium vehicle';
    final category = json['category']?.toString() ?? name;
    final seats = (json['seats'] as num?)?.toInt() ?? 0;
    final luggage = (json['luggage'] as num?)?.toInt() ??
        (json['bags'] as num?)?.toInt() ??
        0;
    // Round, don't truncate: 90.86 must display as 91, never 90.
    final price = (json['base_price'] as num?)?.round() ??
        (json['price'] as num?)?.round() ??
        0;
    return Vehicle(
      id: (json['id'] as num?)?.toInt() ?? fallbackId,
      // The API serializes Mongo docs with the raw `_id` key (NOT `id`).
      // This is the join key for real price quotes — reading the wrong key
      // silently discarded every quote and forced the TND fallback.
      backendId: (json['_id'] ?? json['id'])?.toString() ?? '',
      name: name,
      model: json['model']?.toString() ?? category,
      capacity: seats > 0 ? '$seats seats' : 'Premium capacity',
      bags: luggage,
      label: category,
      labelGold: category.toLowerCase() == 'vip',
      price: price,
      image: json['image_url']?.toString() ??
          json['image']?.toString() ??
          'assets/images/fleet/mercedes-e-class-2024-carthage-transfer.webp',
      seats: seats,
      category: category,
      available: json['availability'] as bool? ?? true,
    );
  }

  int get seatCount {
    if (seats > 0) return seats;
    final match = RegExp(r'\d+')
        .allMatches(capacity)
        .map((m) => int.tryParse(m.group(0) ?? '') ?? 0);
    return match.isEmpty ? 0 : match.reduce((a, b) => a > b ? a : b);
  }
}
