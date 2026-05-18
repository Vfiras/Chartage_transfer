class FavoriteLocation {
  final String id;
  final String label;
  final String address;
  final String type;

  const FavoriteLocation({
    required this.id,
    required this.label,
    required this.address,
    required this.type,
  });

  factory FavoriteLocation.fromJson(Map<String, dynamic> json) {
    return FavoriteLocation(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Favorite',
      address: json['address']?.toString() ?? '',
      type: json['type']?.toString() ?? 'custom',
    );
  }
}
