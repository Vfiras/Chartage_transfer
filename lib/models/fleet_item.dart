class FleetItem {
  final int id;
  final String name;
  final String model;
  final String category;
  final int pax;
  final int bags;
  final String comfort;
  final List<String> features;
  final String price;
  final String image;

  const FleetItem({
    required this.id,
    required this.name,
    required this.model,
    required this.category,
    required this.pax,
    required this.bags,
    required this.comfort,
    required this.features,
    required this.price,
    required this.image,
  });

  String get title => name;
  String get imageUrl => image;
  String get vehicleType => model;
  int get passengers => pax;
  double get priceMin {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(price);
    return double.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
