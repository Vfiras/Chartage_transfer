import 'package:flutter/material.dart';
import '../data/destinations_data.dart';
import '../core/constants/app_colors.dart';
import '../widgets/common/fallback_network_image.dart';

class DestinationsScreen extends StatefulWidget {
  const DestinationsScreen({super.key});

  @override
  State<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends State<DestinationsScreen> {
  String filter = 'All';

  @override
  Widget build(BuildContext context) {
    // The chips are a real control: filter routes by city (either endpoint).
    final routes = filter == 'All'
        ? DestinationsData.routes
        : DestinationsData.routes
            .where((r) => r.from.contains(filter) || r.to.contains(filter))
            .toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Routes & Pricing',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: DestinationsData.filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final f = DestinationsData.filters[i];
                  final on = f == filter;
                  return GestureDetector(
                    onTap: () => setState(() => filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // Selected = gold, like every other chip in the app.
                        color: on ? AppColors.secondary : AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color:
                                on ? AppColors.secondary : AppColors.softBorder),
                      ),
                      child: Text(f,
                          style: TextStyle(
                              color: on
                                  ? const Color(0xFF221A08)
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: routes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_outlined,
                              color: AppColors.textMuted, size: 40),
                          const SizedBox(height: 12),
                          Text('No routes for this destination yet.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      itemCount: routes.length,
                      itemBuilder: (_, i) {
                        final r = routes[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.softBorder),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(20)),
                                child: SizedBox(
                                  width: 110,
                                  height: 112,
                                  child: FallbackNetworkImage(
                                      url: r.image, fit: BoxFit.cover),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(r.from,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted)),
                                      const SizedBox(height: 3),
                                      Text(r.to,
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${r.price} TND',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  color: AppColors.secondary,
                                                  fontWeight:
                                                      FontWeight.w800)),
                                          Row(
                                            children: [
                                              Icon(Icons.schedule_rounded,
                                                  size: 13,
                                                  color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Text(r.time,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textSecondary)),
                                            ],
                                          )
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
