import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/common/luxury_components.dart';
import 'admin_bookings_screen.dart';
import 'admin_cars_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_pricing_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_promotions_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _setIndex(int value) => setState(() => _index = value);

  void _pushPromotions() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminPromotionsScreen()),
    );
  }

  void _pushPricing() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminPricingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AdminDashboardScreen(
        onOpenBookings: () => _setIndex(1),
        onOpenFleet: () => _setIndex(2),
        onOpenPromotions: _pushPromotions,
        onOpenPricing: _pushPricing,
      ),
      const AdminBookingsScreen(),
      const AdminCarsScreen(),
      const AdminProfileScreen(),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: AppColors.background,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: LuxuryBottomNav(
          index: _index,
          onChanged: _setIndex,
          items: const [
            LuxuryBottomNavItem(
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              label: 'Dashboard',
            ),
            LuxuryBottomNavItem(
              icon: Icons.receipt_long_outlined,
              activeIcon: Icons.receipt_long_rounded,
              label: 'Bookings',
            ),
            LuxuryBottomNavItem(
              icon: Icons.directions_car_outlined,
              activeIcon: Icons.directions_car_rounded,
              label: 'Fleet',
            ),
            LuxuryBottomNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
