import 'dart:ui';
import 'package:flutter/material.dart';

import '../navigation/app_tab.dart';
import '../navigation/app_nav_controller.dart';
import '../screens/about_screen.dart';
import '../screens/booking_screen.dart';
import '../screens/destinations_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/services_screen.dart';
import '../screens/support_screen.dart';
import '../screens/vehicles_screen.dart';
import '../navigation/custom_bottom_nav.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final AppNavController nav = AppNavController();

  @override
  void dispose() {
    nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: nav,
      builder: (context, _) {
        return Scaffold(
          extendBody: true, // must be true
          body: _currentScreen(),

          // 👇 blurred transparent strip UNDER your existing white rounded nav
          bottomNavigationBar: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                color: Colors.white
                    .withValues(alpha: 0.05), // transparent glass strip
                child: CustomBottomNav(
                  current: nav.currentTab,
                  onChanged: nav.goToTab,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _currentScreen() {
    switch (nav.currentTab) {
      case AppTab.home:
        return HomeScreen(
          onOpenBooking: () => nav.goToTab(AppTab.book),
          onOpenVehicles: () => nav.goToTab(AppTab.vehicles),
          onOpenServices: () => nav.goToTab(AppTab.services),
          onOpenSupport: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SupportScreen(
                  onOpenAbout: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                ),
              ),
            );
          },
          onOpenDestinations: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DestinationsScreen()),
            );
          },
          onOpenAbout: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            );
          },
        );

      case AppTab.book:
        return const BookingScreen();

      case AppTab.vehicles:
        return const VehiclesScreen();

      case AppTab.services:
        return const ServicesScreen();

      case AppTab.profile:
        return ProfileScreen(
          onBack: () => nav.goToTab(AppTab.home),
          onLogout: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          },
        );
    }
  }
}
