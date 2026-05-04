import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../role_profile_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  List<Widget> get _tabs => [
        const _AdminHomeTab(),
        const _BookingsTab(),
        const _UsersTab(),
        RoleProfileScreen(
          title: 'Management tools',
          subtitle: 'Admin controls, team oversight, and account actions.',
          name: 'Admin',
          roleLabel: 'Administrator',
          email: 'admin',
          phone: 'admin',
          actions: [
            RoleAction(
              icon: Icons.dashboard_outlined,
              title: 'System Overview',
              subtitle: 'View dashboard metrics and operations',
              onTap: () {},
            ),
            RoleAction(
              icon: Icons.group_outlined,
              title: 'Manage Users',
              subtitle: 'Review drivers and clients',
              onTap: () {},
            ),
            RoleAction(
              icon: Icons.settings_outlined,
              title: 'Admin Settings',
              subtitle: 'App preferences and permissions',
              onTap: () {},
            ),
          ],
        ),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group_rounded),
            label: 'Users',
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

class _AdminHomeTab extends StatelessWidget {
  const _AdminHomeTab();

  @override
  Widget build(BuildContext context) {
    final stats = [
      _AdminStat('Total bookings', '284'),
      _AdminStat('Active drivers', '19'),
      _AdminStat('Revenue', '48.6K'),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Admin Dashboard',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'A simplified overview for bookings, fleet activity, and revenue.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 400) {
                return Column(
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      _StatCard(item: stats[i]),
                      if (i != stats.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    Expanded(child: _StatCard(item: stats[i])),
                    if (i != stats.length - 1) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BookingsTab extends StatelessWidget {
  const _BookingsTab();

  @override
  Widget build(BuildContext context) {
    final bookings = [
      _BookingItem('Leila Ben Youssef', 'Airport to La Marsa', 'Confirmed'),
      _BookingItem('Ahmed Khelifi', 'Hotel to Airport', 'Pending'),
      _BookingItem('Sana Trabelsi', 'Airport to Sidi Bou Said', 'Completed'),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Bookings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          ...bookings.map((booking) => _BookingCard(item: booking)),
        ],
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    final users = [
      _UserItem('Nabil', 'Driver', true),
      _UserItem('Mourad', 'Driver', false),
      _UserItem('Leila', 'Client', true),
      _UserItem('Sana', 'Client', true),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Users',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          ...users.map((user) => _UserCard(item: user)),
        ],
      ),
    );
  }
}

class _AdminStat {
  final String label;
  final String value;

  const _AdminStat(this.label, this.value);
}

class _StatCard extends StatelessWidget {
  final _AdminStat item;

  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingItem {
  final String client;
  final String route;
  final String status;

  const _BookingItem(this.client, this.route, this.status);
}

class _BookingCard extends StatelessWidget {
  final _BookingItem item;

  const _BookingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.client,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.route,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _StatusPill(text: item.status),
          ),
        ],
      ),
    );
  }
}

class _UserItem {
  final String name;
  final String role;
  final bool active;

  const _UserItem(this.name, this.role, this.active);
}

class _UserCard extends StatelessWidget {
  final _UserItem item;

  const _UserCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: item.role == 'Driver'
                ? const Color(0xFFFFF3C4)
                : const Color(0xFFEAF2FF),
            child: Icon(
              item.role == 'Driver'
                  ? Icons.drive_eta_rounded
                  : Icons.person_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.role,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _StatusPill(text: item.active ? 'Active' : 'Offline'),
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
    final active =
        text.toLowerCase() == 'active' || text.toLowerCase() == 'confirmed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF0FFF4) : const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? AppColors.green : AppColors.primary,
        ),
      ),
    );
  }
}
