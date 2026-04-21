import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/common/fallback_network_image.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reviews = [
      'Absolutely seamless. Driver was at the gate with a name-board.',
      'Professional, punctual, and price exactly as quoted.',
      'Safe and on-time. Very reassuring service.',
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            const Text('About Us',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.softBorder),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    child: FallbackNetworkImage(
                      url:
                          'https://images.unsplash.com/photo-1558222209-134191edfe0d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1200',
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Carthage Transfer is dedicated to reliable, premium private transfers across Tunisia.',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                _Metric('12+', 'Years'),
                SizedBox(width: 8),
                _Metric('2,400+', 'Rides'),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                _Metric('4.9★', 'Rating'),
                SizedBox(width: 8),
                _Metric('24/7', 'Support'),
              ],
            ),
            const SizedBox(height: 14),
            const Text('What Passengers Say',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...reviews.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.softBorder),
                  ),
                  child: Text('“$r”',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.55)),
                )),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String v;
  final String l;
  const _Metric(this.v, this.l);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.softBorder),
        ),
        child: Column(
          children: [
            Text(v,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondary)),
            const SizedBox(height: 2),
            Text(l,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
