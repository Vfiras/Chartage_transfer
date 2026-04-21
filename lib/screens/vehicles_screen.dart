import 'package:flutter/material.dart';
import '../data/fleet_data.dart';
import '../theme/app_colors.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Our Vehicles',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: FleetData.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = FleetData.categories[i];
                  final on = c == active;
                  return GestureDetector(
                    onTap: () => setState(() => active = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.softBorder),
                      ),
                      child: Text(c,
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
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final v = filtered[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.softBorder),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 24,
                            offset: Offset(0, 6))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24)),
                          child: SizedBox(
                            height: 160,
                            width: double.infinity,
                            child: FallbackNetworkImage(
                                url: v.image, fit: BoxFit.cover),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.name,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(v.model,
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFFAAAAAA))),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.groups_rounded,
                                      size: 15, color: AppColors.secondary),
                                  const SizedBox(width: 4),
                                  Text('Up to ${v.pax}',
                                      style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.luggage_rounded,
                                      size: 15, color: AppColors.secondary),
                                  const SizedBox(width: 4),
                                  Text('${v.bags} bags',
                                      style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...v.features.map((f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        const Icon(
                                            Icons.check_circle_outline_rounded,
                                            size: 14,
                                            color: AppColors.secondary),
                                        const SizedBox(width: 6),
                                        Text(f,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppColors.textSecondary)),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 6),
                              Text(v.price,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.secondary)),
                            ],
                          ),
                        ),
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
