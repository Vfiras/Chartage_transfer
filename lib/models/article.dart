class Article {
  final String id;
  final String title;
  final String excerpt;
  final String imageUrl;
  final String publishedAt;
  final String slug;

  const Article({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.imageUrl,
    required this.publishedAt,
    required this.slug,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      title: json['title'] as String,
      excerpt: json['excerpt'] as String,
      imageUrl: json['image_url'] as String,
      publishedAt: json['published_at'] as String,
      slug: json['slug'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'excerpt': excerpt,
      'image_url': imageUrl,
      'published_at': publishedAt,
      'slug': slug,
    };
  }
}
