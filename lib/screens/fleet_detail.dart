import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/fleet_item.dart';
import '../themes/app_theme.dart';

class FleetDetailScreen extends StatelessWidget {
  final FleetItem item;

  const FleetDetailScreen({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: item.imageUrl,
              height: 230,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            item.vehicleType,
            style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _Spec(icon: Icons.groups_rounded, label: '${item.passengers} Passengers'),
              const SizedBox(width: 12),
              _Spec(icon: Icons.luggage_rounded, label: '${item.bags} Bags'),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Starting from ${item.priceMin.toStringAsFixed(2)} €',
            style: const TextStyle(
              color: AppTheme.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
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

  const _Spec({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryText),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}
