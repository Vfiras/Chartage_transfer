import 'package:flutter/material.dart';
import '../../data/home_data.dart';
import '../../theme/app_colors.dart';
import '../common/fallback_network_image.dart';
import 'section_header.dart';

class VehicleCarousel extends StatelessWidget {
  final VoidCallback onSeeAll;
  final VoidCallback onSelectVehicle;

  const VehicleCarousel({
    super.key,
    required this.onSeeAll,
    required this.onSelectVehicle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: 'Our Fleet',
          subtitle: 'All with professional driver',
          onSeeAll: onSeeAll,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: HomeData.vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final v = HomeData.vehicles[index];
              return GestureDetector(
                onTap: onSelectVehicle,
                child: Container(
                  width: 160,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.softBorder),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 22,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _vehicleImage(v.image, v.label, v.labelGold, v.price),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              v.model,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 10),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.groups_rounded,
                                    size: 12, color: AppColors.textHint),
                                const SizedBox(width: 4),
                                Text(
                                  v.capacity,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.luggage_rounded,
                                    size: 12, color: AppColors.textHint),
                                const SizedBox(width: 4),
                                Text(
                                  '${v.bags}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _vehicleImage(String image, String label, bool gold, int price) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: SizedBox(
        height: 108,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FallbackNetworkImage(url: image, fit: BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x6B000000)],
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      gold ? const Color(0xF2FFB400) : const Color(0xD1111111),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: gold ? AppColors.primary : Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: RichText(
                text: TextSpan(
                  text: '$price',
                  style: const TextStyle(
                    color: AppColors.secondaryLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  children: const [
                    TextSpan(
                      text: ' TND',
                      style: TextStyle(
                        color: Color(0xB3FFFFFF),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
