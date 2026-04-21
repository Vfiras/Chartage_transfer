import 'package:flutter/material.dart';
import '../data/destinations_data.dart';
import '../theme/app_colors.dart';
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
    const routes = DestinationsData.routes;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.softBorder),
                      ),
                      child: Text(f,
                          style: TextStyle(
                              color:
                                  on ? Colors.white : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                itemCount: routes.length,
                itemBuilder: (_, i) {
                  final r = routes[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.softBorder),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(22)),
                          child: SizedBox(
                            width: 110,
                            height: 100,
                            child: FallbackNetworkImage(
                                url: r.image, fit: BoxFit.cover),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.from,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF888888))),
                                const SizedBox(height: 2),
                                Text(r.to,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${r.price} TND',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800)),
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule_rounded,
                                            size: 13, color: Color(0xFF888888)),
                                        const SizedBox(width: 4),
                                        Text(r.time,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textSecondary)),
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
