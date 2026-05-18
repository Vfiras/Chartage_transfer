import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../data/fleet_data.dart';
import '../shared/widgets/common/luxury_components.dart';
import '../widgets/common/fallback_network_image.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  String active = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = active == 'All'
        ? FleetData.items
        : FleetData.items.where((e) => e.category == active).toList();

    return LuxuryScaffold(
      title: 'Premium Fleet',
      subtitle: '11 vehicles for airport and group transfers',
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: FleetData.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final category = FleetData.categories[i];
                final selected = category == active;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) => setState(() => active = category),
                  selectedColor: AppColors.secondary,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                      color: selected ? AppColors.secondary : AppColors.border),
                  labelStyle: TextStyle(
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w900,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          for (final item in filtered)
            LuxuryCard(
              margin: const EdgeInsets.only(bottom: 14),
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                    child: FallbackNetworkImage(
                        url: item.image,
                        height: 168,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(item.name,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900))),
                            LuxuryStatusChip(label: item.category),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(item.model,
                            style: const TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _Spec(
                                icon: Icons.groups_rounded,
                                label: 'Up to ${item.pax}'),
                            const SizedBox(width: 10),
                            _Spec(
                                icon: Icons.luggage_rounded,
                                label: '${item.bags} bags'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: item.features
                              .map(
                                (feature) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border:
                                        Border.all(color: AppColors.goldBorder),
                                  ),
                                  child: Text(feature,
                                      style: const TextStyle(
                                          color: AppColors.secondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                        Text(item.price,
                            style: const TextStyle(
                                color: AppColors.secondary,
                                fontSize: 19,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Spec({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.secondary, size: 17),
            const SizedBox(width: 7),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}
