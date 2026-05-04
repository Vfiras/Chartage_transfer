class Review {
  final String id;
  final String googleReviewId;
  final String author;
  final String avatarUrl;
  final String text;
  final double rating;
  final String createdAt;
  final bool verified;
  final String language;
  final String reviewUrl;

  const Review({
    required this.id,
    required this.googleReviewId,
    required this.author,
    required this.avatarUrl,
    required this.text,
    required this.rating,
    required this.createdAt,
    required this.verified,
    required this.language,
    required this.reviewUrl,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      googleReviewId: json['google_review_id'] as String,
      author: json['author'] as String,
      avatarUrl: json['avatar_url'] as String,
      text: json['text'] as String,
      rating: (json['rating'] as num).toDouble(),
      createdAt: json['created_at'] as String,
      verified: json['verified'] as bool,
      language: json['language'] as String,
      reviewUrl: json['review_url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'google_review_id': googleReviewId,
      'author': author,
      'avatar_url': avatarUrl,
      'text': text,
      'rating': rating,
      'created_at': createdAt,
      'verified': verified,
      'language': language,
      'review_url': reviewUrl,
    };
  }
}
