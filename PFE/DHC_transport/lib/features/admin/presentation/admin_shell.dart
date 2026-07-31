import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/client/premium_client_components.dart';
import 'admin_bookings_screen.dart';
import 'admin_cars_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_pricing_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_promotions_screen.dart';
import 'admin_suppliers_screen.dart';

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

  void _pushComplaints() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminComplaintsScreen()),
    );
  }

  void _pushSuppliers() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminSuppliersScreen()),
    );
  }

  void _pushRecommendations() {
    Navigator.of(context).pushNamed(AppRoutes.recommendationManagement);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AdminDashboardScreen(
        onOpenBookings: () => _setIndex(1),
        onOpenFleet: () => _setIndex(2),
        onOpenPromotions: _pushPromotions,
        onOpenPricing: _pushPricing,
        onOpenComplaints: _pushComplaints,
        onOpenSuppliers: _pushSuppliers,
        onOpenRecommendations: _pushRecommendations,
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
        // extendBody lets content scroll behind the floating pill, matching
        // the client shell's treatment of the same nav.
        extendBody: true,
        body: IndexedStack(index: _index, children: tabs),
        // Same glassmorphic pill as the client app — PremiumClientNav already
        // takes its items as a parameter, so admin reuses it as-is instead of
        // keeping a second, visually weaker nav implementation.
        bottomNavigationBar: PremiumClientNav(
          index: _index,
          onChanged: _setIndex,
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 22),
          items: const [
            PremiumNavItem(
              label: 'Dashboard',
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
            ),
            PremiumNavItem(
              label: 'Bookings',
              icon: Icons.calendar_today_outlined,
              activeIcon: Icons.calendar_today_rounded,
            ),
            PremiumNavItem(
              label: 'Fleet',
              icon: Icons.directions_car_outlined,
              activeIcon: Icons.directions_car_rounded,
            ),
            PremiumNavItem(
              label: 'Profile',
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
