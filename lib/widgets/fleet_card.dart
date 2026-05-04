import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../models/fleet_item.dart';
import '../themes/app_theme.dart';
import 'common/fallback_network_image.dart';

class FleetCard extends StatefulWidget {
  final FleetItem item;
  final VoidCallback onTap;

  const FleetCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<FleetCard> createState() => _FleetCardState();
}

class _FleetCardState extends State<FleetCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.1 : 1,
        duration: const Duration(milliseconds: 180),
        child: Semantics(
          button: true,
          label: 'Open ${widget.item.title} fleet details',
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
                boxShadow: _hovering ? const [AppTheme.cardShadow] : const [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FallbackNetworkImage(
                        url: widget.item.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SpecChip(
                          icon: Icons.groups_rounded,
                          text: '${widget.item.passengers} Passengers',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SpecChip(
                          icon: Icons.luggage_rounded,
                          text: '${widget.item.bags} Bags',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SpecChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: AppTheme.subtleGray,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: AppTheme.primaryText),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppTheme.primaryText),
          ),
        ),
      ],
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE7E7E7),
      highlightColor: Colors.white,
      child: Container(color: Colors.white),
    );
  }
}
