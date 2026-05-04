import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/admin/admin_card.dart';

class AdminDashboardScreen extends StatelessWidget {
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenSuppliers;

  const AdminDashboardScreen({
    super.key,
    required this.onOpenBookings,
    required this.onOpenSuppliers,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      const _DashboardStat('Total bookings', '284', Icons.receipt_long_rounded),
      const _DashboardStat('Revenue', '48.6K', Icons.payments_rounded),
      const _DashboardStat('Active suppliers', '19', Icons.groups_rounded),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
        children: [
          const _Header(),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final stat in stats)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 2,
                  child: AdminCard(
                    label: stat.label,
                    value: stat.value,
                    icon: stat.icon,
                    accentColor: AppColors.secondary,
                    compact: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          AdminCard(
            label: 'Weekly revenue',
            value: '\$48.6K',
            subtitle: 'Compact chart for the last 7 days',
            icon: Icons.show_chart_rounded,
            child: const _MiniChart(),
          ),
          const SizedBox(height: 18),
          AdminCard(
            label: 'Quick actions',
            value: 'Manage operations',
            subtitle: 'Shortcuts for daily admin tasks',
            icon: Icons.flash_on_rounded,
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.receipt_long_rounded,
                  title: 'Open bookings',
                  subtitle: 'Review and manage trips',
                  onTap: onOpenBookings,
                ),
                const SizedBox(height: 10),
                _ActionRow(
                  icon: Icons.group_rounded,
                  title: 'Open suppliers',
                  subtitle: 'Manage supplier partners',
                  onTap: onOpenSuppliers,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'RECENT ACTIVITY',
            style: TextStyle(
              color: Color(0xFF8A8A8A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const _ActivityCard(
            title: 'Booking BK-7829 confirmed',
            subtitle: 'Today, 14:30',
            accent: AppColors.secondary,
          ),
          const SizedBox(height: 10),
          const _ActivityCard(
            title: 'Supplier Elite Transfers updated',
            subtitle: 'Today, 13:10',
            accent: Color(0xFF55D17A),
          ),
          const SizedBox(height: 10),
          const _ActivityCard(
            title: 'Revenue payout processed',
            subtitle: 'Today, 11:05',
            accent: Color(0xFF6F9CFF),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Mobile admin overview for bookings, suppliers, and revenue.',
          style: TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _DashboardStat {
  final String label;
  final String value;
  final IconData icon;

  const _DashboardStat(this.label, this.value, this.icon);
}

class _MiniChart extends StatelessWidget {
  const _MiniChart();

  @override
  Widget build(BuildContext context) {
    final values = [0.32, 0.55, 0.42, 0.68, 0.82, 0.61, 0.75];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 120,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final value in values) ...[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 96 * value,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: [AppColors.secondaryLight, AppColors.secondary],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 4,
                      width: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3A3A3A),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              if (value != values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF131313),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.secondary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF909090),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF747474)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;

  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF909090),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
