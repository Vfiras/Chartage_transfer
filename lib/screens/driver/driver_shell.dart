import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/driver/driver_bottom_nav.dart';
import 'driver_active_trip_screen.dart';
import 'driver_home_screen.dart';
import 'driver_profile_screen.dart';
import 'driver_ride_requests_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _index = 0;
  bool _online = true;

  void _selectTab(int value) {
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DriverHomeScreen(
        driverName: 'Ahmed',
        online: _online,
        onOnlineChanged: (value) => setState(() => _online = value),
        onOpenRequests: () => _selectTab(1),
        onOpenActiveTrip: () => _selectTab(2),
      ),
      const DriverRideRequestsScreen(),
      const DriverActiveTripScreen(),
      const DriverProfileScreen(),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: AppColors.darkBackground,
        navigationBarTheme: const NavigationBarThemeData(
          indicatorColor: Colors.transparent,
        ),
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.darkBackground,
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: DriverBottomNav(
          currentIndex: _index,
          onChanged: _selectTab,
        ),
      ),
    );
  }
}
