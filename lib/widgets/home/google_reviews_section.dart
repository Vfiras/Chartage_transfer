import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'section_header.dart';

class GoogleReviewsSection extends StatelessWidget {
  const GoogleReviewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final reviews = [
      _GoogleReview(
        name: 'S Y',
        time: '1 month ago',
        rating: 5,
        text: 'Bonjour, the transfer went perfectly. The driver was punctual and very professional.',
        avatarColor: const Color(0xFF00897B),
      ),
      _GoogleReview(
        name: 'Hazel Davidson',
        time: '1 month ago',
        rating: 5,
        text: 'Easy to book, driver was professional and efficient. Luxury service from start to finish.',
        avatarColor: const Color(0xFF7C4DFF),
      ),
      _GoogleReview(
        name: 'Anis Fekih',
        time: '1 month ago',
        rating: 5,
        text: 'This is my third time using Carthage Transfer. Excellent service every time.',
        avatarColor: const Color(0xFFFF6F21),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Google Reviews',
          subtitle: 'What our customers say',
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final review = reviews[index];
              return Container(
                width: 260,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.softBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: review.avatarColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            review.name.isNotEmpty ? review.name[0] : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                review.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                review.time,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const _GoogleBadge(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ...List.generate(
                          review.rating,
                          (_) => const Padding(
                            padding: EdgeInsets.only(right: 2),
                            child: Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFC107),
                              size: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            color: Color(0xFF34A853), size: 14),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      review.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GoogleReview {
  final String name;
  final String time;
  final int rating;
  final String text;
  final Color avatarColor;

  const _GoogleReview({
    required this.name,
    required this.time,
    required this.rating,
    required this.text,
    required this.avatarColor,
  });
}

class _GoogleBadge extends StatelessWidget {
  const _GoogleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Google',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
