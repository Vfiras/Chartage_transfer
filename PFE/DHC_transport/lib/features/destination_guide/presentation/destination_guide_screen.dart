import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/common/map_placeholder.dart';
import '../data/destination_guide_repository.dart';
import '../domain/destination_recommendation.dart';
import 'destination_detail_screen.dart';
import 'widgets/recommendation_card.dart';

class DestinationGuideScreen extends StatefulWidget {
  final String destination;

  const DestinationGuideScreen({
    super.key,
    required this.destination,
  });

  @override
  State<DestinationGuideScreen> createState() => _DestinationGuideScreenState();
}

class _DestinationGuideScreenState extends State<DestinationGuideScreen> {
  final _repository = const DestinationGuideRepository();
  RecommendationCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final all = _selectedCategory == null
        ? _repository.forDestination(widget.destination)
        : _repository
            .byCategory(_selectedCategory!)
            .where((item) => '${item.city} ${item.region} ${item.name}'
                .toLowerCase()
                .contains(widget.destination.toLowerCase()))
            .toList(growable: false);
    final featured = all.where((item) => item.featured).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Destination Guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE8E0CC)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destination Guide',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Premium suggestions for ${widget.destination}. Use these cards to guide tourists confidently.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const _SearchBar(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CategoryBar(
            selected: _selectedCategory,
            onSelected: (category) {
              setState(() {
                _selectedCategory = category;
              });
            },
          ),
          const SizedBox(height: 16),
          MapPlaceholder(
            title: 'Map preview for ${widget.destination}',
            subtitle: 'Google Maps integration coming later',
            etaLabel: '12 min',
          ),
          const SizedBox(height: 16),
          const Text(
            'Featured nearby',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (featured.isEmpty)
            const _EmptyState()
          else
            for (final item in featured) ...[
              RecommendationCard(
                item: item,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DestinationDetailScreen(item: item),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6D7B2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.textMuted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Search restaurants, hotels, cafes...',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final RecommendationCategory? selected;
  final ValueChanged<RecommendationCategory?> onSelected;

  const _CategoryBar({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = <RecommendationCategory?>[
      null,
      RecommendationCategory.restaurant,
      RecommendationCategory.hotel,
      RecommendationCategory.cafe,
      RecommendationCategory.activity,
      RecommendationCategory.attraction,
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final active = item == selected;
          return ChoiceChip(
            label: Text(item?.label ?? 'All'),
            selected: active,
            onSelected: (_) => onSelected(item),
            labelStyle: TextStyle(
              color: active ? AppColors.primary : AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
            selectedColor: AppColors.secondary,
            backgroundColor: AppColors.surface,
            side: const BorderSide(color: Color(0xFFE6D7B2)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E0CC)),
      ),
      child: const Text(
        'No recommendations for this filter yet. Add more destinations from the admin dashboard.',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}
