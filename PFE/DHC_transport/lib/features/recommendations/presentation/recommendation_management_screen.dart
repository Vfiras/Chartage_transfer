import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/transport_api_client.dart';
import '../../destination_guide/data/destination_guide_repository.dart';
import '../../destination_guide/domain/destination_recommendation.dart';
import '../../destination_guide/presentation/widgets/recommendation_card.dart';

class RecommendationManagementScreen extends StatefulWidget {
  const RecommendationManagementScreen({super.key});

  @override
  State<RecommendationManagementScreen> createState() =>
      _RecommendationManagementScreenState();
}

class _RecommendationManagementScreenState
    extends State<RecommendationManagementScreen> {
  final _repository = const DestinationGuideRepository();
  RecommendationCategory? _selectedCategory;
  late Future<List<DestinationRecommendation>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchAll();
  }

  void _reload() {
    setState(() {
      _future = _repository.fetchAll(category: _selectedCategory);
    });
  }

  Future<void> _openCreateSheet() async {
    if (_busy) return;
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _GuideItemSheet(),
    );
    if (payload == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await TransportApiClient.instance.post('/recommendations/', payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guide item added')),
      );
      _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectCategory(RecommendationCategory? category) {
    setState(() {
      _selectedCategory = category;
      _future = _repository.fetchAll(category: category);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Recommendation Management'),
        actions: [
          IconButton(
            onPressed: _openCreateSheet,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              FutureBuilder<List<DestinationRecommendation>>(
                future: _future,
                builder: (context, snapshot) {
                  final items = snapshot.data ??
                      (_selectedCategory == null
                          ? _repository.all()
                          : _repository.byCategory(_selectedCategory!));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatsHeader(total: items.length),
                      const SizedBox(height: 16),
                      _CategoryBar(
                        selected: _selectedCategory,
                        onSelected: _selectCategory,
                      ),
                      const SizedBox(height: 16),
                      if (snapshot.hasError)
                        _InfoCard(
                          title: 'Backend unavailable',
                          subtitle: snapshot.error.toString(),
                        )
                      else
                        for (final item in items) ...[
                          RecommendationCard(item: item, compact: true),
                          const SizedBox(height: 12),
                        ],
                    ],
                  );
                },
              ),
            ],
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add guide item'),
      ),
    );
  }
}

class _GuideItemSheet extends StatefulWidget {
  const _GuideItemSheet();

  @override
  State<_GuideItemSheet> createState() => _GuideItemSheetState();
}

class _GuideItemSheetState extends State<_GuideItemSheet> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController(text: 'Bizerte');
  final _regionController = TextEditingController(text: 'Ras Jbal');
  final _ratingController = TextEditingController(text: '4.6');
  final _priceController = TextEditingController(text: r'$$');
  final _descriptionController = TextEditingController();
  final _tagsController =
      TextEditingController(text: 'Tourist friendly, Premium');
  final _phoneController = TextEditingController(text: '+216 20 000 000');
  final _hoursController = TextEditingController(text: '09:00 - 22:00');
  final _imageController = TextEditingController(
    text:
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1200&q=80',
  );
  RecommendationCategory _category = RecommendationCategory.restaurant;
  bool _featured = true;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _ratingController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _phoneController.dispose();
    _hoursController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final tags = _tagsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    Navigator.of(context).pop({
      'destination_id': 'dest-bizerte-ras-jbal',
      'city': _cityController.text.trim(),
      'region': _regionController.text.trim(),
      'name': name,
      'category': _category.name,
      'rating': double.tryParse(_ratingController.text.trim()) ?? 0,
      'visible': true,
      'description': _descriptionController.text.trim().isEmpty
          ? '$name recommendation created by admin.'
          : _descriptionController.text.trim(),
      'image_url': _imageController.text.trim(),
      'price_range': _priceController.text.trim(),
      'tags': tags,
      'notes': 'Created from the admin guide form.',
      'phone': _phoneController.text.trim(),
      'opening_hours': _hoursController.text.trim(),
      'primary_label': _primaryLabel,
      'primary_value': _primaryValue,
      'secondary_label': 'Area',
      'secondary_value': _regionController.text.trim(),
      'tertiary_label': 'Best for',
      'tertiary_value': 'Tourists',
      'featured': _featured,
    });
  }

  String get _primaryLabel => switch (_category) {
        RecommendationCategory.restaurant => 'Food Type',
        RecommendationCategory.hotel => 'Stars',
        RecommendationCategory.cafe => 'Type',
        RecommendationCategory.activity => 'Activity',
        RecommendationCategory.attraction => 'Sight',
      };

  String get _primaryValue => switch (_category) {
        RecommendationCategory.restaurant => 'Restaurant',
        RecommendationCategory.hotel => '4-Star',
        RecommendationCategory.cafe => 'Cafe',
        RecommendationCategory.activity => 'Guided activity',
        RecommendationCategory.attraction => 'Attraction',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Add Guide Item',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<RecommendationCategory>(
              initialValue: _category,
              decoration: _inputDecoration('Category'),
              items: RecommendationCategory.values
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item.label)))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 10),
            _EditField(label: 'Name', controller: _nameController),
            _EditField(label: 'City', controller: _cityController),
            _EditField(label: 'Region', controller: _regionController),
            _EditField(
                label: 'Rating',
                controller: _ratingController,
                keyboardType: TextInputType.number),
            _EditField(label: 'Price range', controller: _priceController),
            _EditField(
                label: 'Tags comma separated', controller: _tagsController),
            _EditField(label: 'Phone', controller: _phoneController),
            _EditField(label: 'Opening hours', controller: _hoursController),
            _EditField(label: 'Image URL', controller: _imageController),
            _EditField(
                label: 'Description',
                controller: _descriptionController,
                maxLines: 3),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _featured,
              title: const Text('Feature for customers'),
              activeThumbColor: AppColors.secondary,
              onChanged: (value) => setState(() => _featured = value),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.primary,
                    ),
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  final int total;

  const _StatsHeader({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: _StatTile(label: 'Total items', value: '$total')),
          Expanded(child: _StatTile(label: 'Visible', value: '$total')),
          const Expanded(child: _StatTile(label: 'Drafts', value: '0')),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
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
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;

  const _EditField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: _inputDecoration(label),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.surfaceElevated,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
  );
}
