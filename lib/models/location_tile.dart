class LocationTile {
  final String id;
  final String origin;
  final String destination;
  final String subLocation;
  final String imageUrl;
  final double startingPrice;

  const LocationTile({
    required this.id,
    required this.origin,
    required this.destination,
    required this.subLocation,
    required this.imageUrl,
    required this.startingPrice,
  });

  factory LocationTile.fromJson(Map<String, dynamic> json) {
    return LocationTile(
      id: json['id'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      subLocation: json['sub_location'] as String,
      imageUrl: json['image_url'] as String,
      startingPrice: (json['starting_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'origin': origin,
      'destination': destination,
      'sub_location': subLocation,
      'image_url': imageUrl,
      'starting_price': startingPrice,
    };
  }
}
