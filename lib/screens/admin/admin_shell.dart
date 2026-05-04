import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'admin_dashboard_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_booking_details_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_suppliers_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _setIndex(int value) {
    setState(() => _index = value);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AdminDashboardScreen(
        onOpenBookings: () => _setIndex(1),
        onOpenSuppliers: () => _setIndex(2),
      ),
      AdminBookingsScreen(
        onOpenBookingDetails: (booking) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminBookingDetailsScreen(booking: booking),
            ),
          );
        },
      ),
      const AdminSuppliersScreen(),
      const AdminProfileScreen(),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: AppColors.darkBackground,
      ),
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: IndexedStack(index: _index, children: tabs),
        bottomNavigationBar: _AdminBottomNav(
          index: _index,
          onChanged: _setIndex,
        ),
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _AdminBottomNav({
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItemData(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
      _NavItemData(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Bookings'),
      _NavItemData(Icons.group_outlined, Icons.group_rounded, 'Suppliers'),
      _NavItemData(Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x1FFFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = index == i;
              final color = active ? AppColors.secondary : const Color(0xFF8A8A8A);
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (active)
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        )
                      else
                        const SizedBox(height: 4),
                      const SizedBox(height: 8),
                      Icon(active ? item.activeIcon : item.icon, color: color, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData(this.icon, this.activeIcon, this.label);
}
