import 'package:flutter/material.dart';

import '../data/fleet_data.dart';
import '../models/fleet_item.dart';
import '../shared/widgets/client/premium_client_components.dart';
import '../widgets/common/fallback_network_image.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  String _active = 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = _active == 'All'
        ? FleetData.items
        : FleetData.items.where((item) => item.category == _active).toList();

    return Scaffold(
      backgroundColor: PremiumClientPalette.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: _FleetHeader(onBack: () => Navigator.of(context).pop()),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'EXECUTIVE SELECTION',
                      style: TextStyle(
                        color: PremiumClientPalette.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Premium Fleet',
                      style: TextStyle(
                        color: PremiumClientPalette.text,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _FilterChips(
                      value: _active,
                      onChanged: (value) => setState(() => _active = value),
                    ),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) =>
                    _PremiumFleetCard(item: filtered[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FleetHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _FleetHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: const Icon(
            Icons.menu_rounded,
            color: PremiumClientPalette.gold,
            size: 28,
          ),
        ),
        const SizedBox(width: 2),
        const Expanded(
          child: Text(
            'Carthage Transfer',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: PremiumClientPalette.gold,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        const PremiumAvatar(size: 42),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FilterChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Sedan', 'SUV', 'Van', 'Bus'];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == value;
          return GestureDetector(
            onTap: () => onChanged(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? PremiumClientPalette.gold
                    : PremiumClientPalette.elevated.withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? PremiumClientPalette.gold
                      : Colors.white.withValues(alpha: 0.08),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color:
                              PremiumClientPalette.gold.withValues(alpha: 0.28),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                category == 'All' ? 'All Fleet' : category,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF402D00)
                      : PremiumClientPalette.text.withValues(alpha: 0.82),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PremiumFleetCard extends StatelessWidget {
  final FleetItem item;

  const _PremiumFleetCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final price = item.price.replaceAll('From ', '');
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
      decoration: BoxDecoration(
        color: PremiumClientPalette.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.36),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 188,
            child: Center(
              child: Container(
                height: 172,
                width: double.infinity,
                color: Colors.white,
                child: FallbackNetworkImage(
                  url: item.image,
                  fit: BoxFit.contain,
                  height: 172,
                  width: double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: PremiumClientPalette.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fleetLabel(item),
                      style: const TextStyle(
                        color: PremiumClientPalette.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: PremiumClientPalette.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '/ per hour',
                    style: TextStyle(
                      color: PremiumClientPalette.text.withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SpecChip(
                  icon: Icons.person_outline_rounded,
                  text: 'Up to ${item.pax}'),
              _SpecChip(
                  icon: Icons.luggage_outlined, text: '${item.bags} Bags'),
              _SpecChip(icon: _featureIcon(item), text: _featureText(item)),
            ],
          ),
        ],
      ),
    );
  }

  String _fleetLabel(FleetItem item) {
    return switch (item.category) {
      'Sedan' =>
        item.name.contains('Premium') ? 'PRESIDENTIAL' : 'BUSINESS CLASS',
      'SUV' => 'PRESIDENTIAL',
      'Van' => item.pax > 8 ? 'GROUP EXECUTIVE' : 'VIP VAN',
      'Bus' => 'CORPORATE GROUP',
      _ => item.comfort.toUpperCase(),
    };
  }

  IconData _featureIcon(FleetItem item) {
    if (item.features
        .any((feature) => feature.toLowerCase().contains('wifi'))) {
      return Icons.wifi_rounded;
    }
    if (item.category == 'SUV') return Icons.star_outline_rounded;
    if (item.category == 'Bus' || item.pax > 8) return Icons.groups_rounded;
    return Icons.verified_user_outlined;
  }

  String _featureText(FleetItem item) {
    if (item.features
        .any((feature) => feature.toLowerCase().contains('wifi'))) {
      return 'Wi-Fi';
    }
    if (item.category == 'SUV') return 'VIP Driver';
    if (item.category == 'Bus' || item.pax > 8) return 'Group Ready';
    return item.comfort;
  }
}

class _SpecChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SpecChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF221F1B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: PremiumClientPalette.text, size: 14),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: PremiumClientPalette.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
