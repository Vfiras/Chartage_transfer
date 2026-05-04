class Sponsor {
  final String id;
  final String name;
  final String logoUrl;
  final String websiteUrl;

  const Sponsor({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.websiteUrl,
  });

  factory Sponsor.fromJson(Map<String, dynamic> json) {
    return Sponsor(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String,
      websiteUrl: json['website_url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logo_url': logoUrl,
      'website_url': websiteUrl,
    };
  }
}
