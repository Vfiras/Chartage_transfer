import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/common/route_map_view.dart';
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
  List<DestinationRecommendation>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _error = null; });
    try {
      final items = await _repository.fetchAll();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load recommendations. Please try again.');
    }
  }

  List<DestinationRecommendation> _filtered() {
    final all = _items ?? const [];
    final needle = widget.destination.toLowerCase();
    return all.where((item) {
      final matchesDestination = '${item.city} ${item.region} ${item.name}'
          .toLowerCase()
          .contains(needle);
      final matchesCategory =
          _selectedCategory == null || item.category == _selectedCategory;
      return matchesDestination && matchesCategory;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Destination Guide'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 48),
          Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }

    if (_items == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final all = _filtered();
    final featured = all.where((item) => item.featured).toList(growable: false);

    return ListView(
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
              Text(
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
                style: TextStyle(
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
          onSelected: (category) => setState(() => _selectedCategory = category),
        ),
        const SizedBox(height: 16),
        RouteMapView.fromStrings(
          destination: widget.destination,
          height: 280,
        ),
        const SizedBox(height: 16),
        Text(
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
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Search restaurants, hotels, cafes...',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
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

  const _CategoryBar({required this.selected, required this.onSelected});

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
      child: Text(
        'No recommendations for this filter yet.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
      ),
    );
  }
}
