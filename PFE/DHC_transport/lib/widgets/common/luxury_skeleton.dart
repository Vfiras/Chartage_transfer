import 'package:flutter/material.dart';

/// Shared shimmer skeleton primitives — loading states shaped like the
/// content they replace, instead of a raw spinner.
///
/// Usage: compose [SkeletonBox]es inside a [SkeletonPulse] (one pulse
/// controller per screen keeps them in sync), or drop in a ready-made
/// [SkeletonCardList] for standard list screens.
class SkeletonPulse extends StatefulWidget {
  final Widget child;

  const SkeletonPulse({super.key, required this.child});

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    // Subtle breath, ease-out, never attention-grabbing.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// A single placeholder shape.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Ready-made list-screen skeleton: N card-shaped placeholders with a
/// title/subtitle/meta structure that matches most list cards in the app.
class SkeletonCardList extends StatelessWidget {
  final int count;
  final double cardHeight;
  final EdgeInsetsGeometry padding;

  const SkeletonCardList({
    super.key,
    this.count = 4,
    this.cardHeight = 108,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SkeletonPulse(
      child: ListView.separated(
        padding: padding,
        // Used inside other scrollables (Columns in ListViews) — must size
        // itself, not expand into an unbounded viewport.
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, __) => Container(
          height: cardHeight,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SkeletonBox(width: 140, height: 14),
              SizedBox(height: 10),
              SkeletonBox(width: 220, height: 11),
              SizedBox(height: 10),
              Row(
                children: [
                  SkeletonBox(width: 72, height: 10),
                  SizedBox(width: 12),
                  SkeletonBox(width: 48, height: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for the vehicle-selection screen: mimics the product card
/// (badge, title lines, image plate, spec row) so the page keeps its
/// structure while quotes load.
class SkeletonVehicleCards extends StatelessWidget {
  final int count;

  const SkeletonVehicleCards({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SkeletonPulse(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonBox(width: 90, height: 18, radius: 999),
                      SkeletonBox(width: 64, height: 18),
                    ],
                  ),
                  SizedBox(height: 12),
                  SkeletonBox(width: 150, height: 16),
                  SizedBox(height: 8),
                  SkeletonBox(width: 110, height: 12),
                  SizedBox(height: 18),
                  SkeletonBox(height: 150, radius: 8),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      SkeletonBox(width: 60, height: 11),
                      SizedBox(width: 14),
                      SkeletonBox(width: 60, height: 11),
                      Spacer(),
                      SkeletonBox(width: 92, height: 40, radius: 999),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
