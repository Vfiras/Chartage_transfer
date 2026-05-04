import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../login_screen.dart';
import '../about_screen.dart';
import '../booking_screen.dart';
import '../destinations_screen.dart';
import '../home_screen.dart';
import '../profile_screen.dart';
import '../services_screen.dart';
import '../support_screen.dart';
import '../vehicles_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;

  List<Widget> get _tabs => [
        HomeScreen(
          onOpenBooking: () => setState(() => _index = 1),
          onOpenVehicles: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VehiclesScreen()),
            );
          },
          onOpenServices: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ServicesScreen()),
            );
          },
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
        ),
        const BookingScreen(),
        const _TripsTab(),
        const _ProfileTab(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFFFF3C4),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Booking',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _TripsTab extends StatelessWidget {
  const _TripsTab();

  @override
  Widget build(BuildContext context) {
    final upcoming = [
      _TripItem(
        title: 'Airport to Downtown',
        subtitle: 'Pickup at Tunis-Carthage Airport',
        time: 'Today, 14:30',
        status: 'Confirmed',
      ),
      _TripItem(
        title: 'Hotel to Airport',
        subtitle: 'Return transfer for tomorrow morning',
        time: 'Tomorrow, 07:15',
        status: 'Scheduled',
      ),
    ];

    final history = [
      _TripItem(
        title: 'Airport to Gammarth',
        subtitle: 'Completed smoothly',
        time: '12 Apr 2026',
        status: 'Completed',
      ),
      _TripItem(
        title: 'City Center to Airport',
        subtitle: 'Business trip transfer',
        time: '09 Apr 2026',
        status: 'Completed',
      ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Trips',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Track upcoming rides and review your recent transfers.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          const _SectionLabel(title: 'Upcoming'),
          const SizedBox(height: 12),
          ...upcoming.map(_TripCard.new),
          const SizedBox(height: 20),
          const _SectionLabel(title: 'History'),
          const SizedBox(height: 12),
          ...history.map(_TripCard.new),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return ProfileScreen(
      onBack: () => setState(() => _index = 0),
      onLogout: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _TripItem {
  final String title;
  final String subtitle;
  final String time;
  final String status;

  const _TripItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.status,
  });
}

class _TripCard extends StatelessWidget {
  final _TripItem item;

  const _TripCard(this.item);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusPill(text: item.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.subtitle,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                item.time,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;

  const _StatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _ProfileAction({
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
