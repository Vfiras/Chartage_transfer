import 'package:flutter/material.dart';

import '../client/premium_client_components.dart';

/// The admin bottom navigation: Dashboard · Bookings · Fleet · Profile.
///
/// The glassmorphic pill itself (ClipRRect + BackdropFilter(18) + translucent
/// fill, gold expansion on the active item, 440px max width, SafeArea bottom
/// inset) is implemented once in [PremiumClientNav] and reused here rather than
/// copied. A second copy of that animation logic would inevitably drift from
/// the client's, and the two bars are meant to look identical — only their
/// destinations differ.
class AdminNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  /// Indices that should show an unread dot.
  final Set<int> badged;

  const AdminNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    this.badged = const {},
  });

  static const items = [
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
  ];

  @override
  Widget build(BuildContext context) {
    return PremiumClientNav(
      index: index,
      onChanged: onChanged,
      badged: badged,
      items: items,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 22),
    );
  }
}
