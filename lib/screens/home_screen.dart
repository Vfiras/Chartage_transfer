import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/home/booking_card.dart';
import '../widgets/home/google_reviews_section.dart';
import '../widgets/home/hero_section.dart';
import '../widgets/home/home_divider.dart';
import '../widgets/home/how_it_works_section.dart';
import '../widgets/home/partners_strip.dart';
import '../widgets/home/popular_routes_section.dart';
import '../widgets/home/trust_elements.dart';
import '../widgets/home/vehicle_carousel.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenBooking;
  final VoidCallback onOpenVehicles;
  final VoidCallback onOpenServices;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenDestinations;
  final VoidCallback onOpenAbout;

  const HomeScreen({
    super.key,
    required this.onOpenBooking,
    required this.onOpenVehicles,
    required this.onOpenServices,
    required this.onOpenSupport,
    required this.onOpenDestinations,
    required this.onOpenAbout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            HeroSection(onBookNowTap: onOpenBooking),

            // Floating booking card (visually separated from hero)
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BookingCard(onSearch: onOpenBooking),
            ),

            // Rest of content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  const TrustElements(),
                  const SizedBox(height: 24),
                  const HomeDivider(),
                  const SizedBox(height: 24),
                  const HowItWorksSection(),
                  const SizedBox(height: 24),
                  const HomeDivider(),
                  const SizedBox(height: 24),
                  PopularRoutesSection(
                    onSeeAll: onOpenDestinations,
                    onSelectRoute: onOpenBooking,
                  ),
                  const SizedBox(height: 24),
                  const HomeDivider(),
                  const SizedBox(height: 24),
                  VehicleCarousel(
                    onSeeAll: onOpenVehicles,
                    onSelectVehicle: onOpenBooking,
                  ),
                  const SizedBox(height: 24),
                  const HomeDivider(),
                  const SizedBox(height: 24),
                  const PartnersStrip(),
                  const SizedBox(height: 16),
                  const GoogleReviewsSection(),
                  const SizedBox(height: 16),

                  // Quick links
                  Row(
                    children: [
                      Expanded(
                        child: _quickLink(
                          label: 'Services',
                          icon: Icons.grid_view_rounded,
                          onTap: onOpenServices,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _quickLink(
                          label: 'Support',
                          icon: Icons.headset_mic_rounded,
                          onTap: onOpenSupport,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _quickLink(
                          label: 'About',
                          icon: Icons.info_outline_rounded,
                          onTap: onOpenAbout,
                        ),
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
  }

  Widget _quickLink({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.softBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.secondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
