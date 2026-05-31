import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../shared/widgets/common/map_placeholder.dart';
import '../domain/destination_recommendation.dart';
import 'widgets/recommendation_card.dart';

class DestinationDetailScreen extends StatelessWidget {
  final DestinationRecommendation item;

  const DestinationDetailScreen({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: Text(item.name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          RecommendationCard(item: item),
          const SizedBox(height: 16),
          MapPlaceholder(
            title: 'Map-ready guide point',
            subtitle: '${item.city}, ${item.region}',
            etaLabel: '12 min',
          ),
          const SizedBox(height: 16),
          _InfoPanel(item: item),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final DestinationRecommendation item;

  const _InfoPanel({required this.item});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _InfoRow(label: 'Description', value: item.description),
      _InfoRow(label: 'Notes', value: item.notes),
      _InfoRow(label: 'Phone', value: item.phone),
      _InfoRow(label: 'Opening Hours', value: item.openingHours),
      _InfoRow(
          label: 'Visibility',
          value: item.visible ? 'Visible to customers' : 'Hidden'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE8E0CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guide details',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
