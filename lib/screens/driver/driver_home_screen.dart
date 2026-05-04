import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/driver/stats_card.dart';

class DriverHomeScreen extends StatelessWidget {
  final String driverName;
  final bool online;
  final ValueChanged<bool> onOnlineChanged;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenActiveTrip;

  const DriverHomeScreen({
    super.key,
    required this.driverName,
    required this.online,
    required this.onOnlineChanged,
    required this.onOpenRequests,
    required this.onOpenActiveTrip,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0x1FFFFFFF)),
              gradient: const LinearGradient(
                colors: [Color(0xFF161616), Color(0xFF111111)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CARTHAGE TRANSFER',
                        style: TextStyle(
                          color: Color(0xFF8B8B8B),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Hello, $driverName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                _OnlinePill(
                  online: online,
                  onChanged: onOnlineChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const StatsCard(
            label: "Today's Earnings",
            value: '\$245.50',
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppColors.secondary,
            large: true,
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Expanded(
                child: _MetricCard(
                  label: 'Completed Trips',
                  value: '4',
                  icon: Icons.check_circle_outline_rounded,
                  color: Color(0xFF66D17A),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: _MetricCard(
                  label: 'Pending Requests',
                  value: '2',
                  icon: Icons.schedule_rounded,
                  color: Color(0xFF5A8DFF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onOpenRequests,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55E6A200),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '2 New Requests',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Tap to view details',
                          style: TextStyle(
                            color: Color(0xFF2B2100),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0x1A000000),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(
                child: StatsCard(
                  label: 'Acceptance',
                  value: '98%',
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: StatsCard(
                  label: 'Rating',
                  value: '4.9',
                  icon: Icons.star_rounded,
                  iconColor: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'RECENT ACTIVITY',
            style: TextStyle(
              color: Color(0xFF8A8A8A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          _ActivityCard(
            title: 'Carthage → La Marsa',
            subtitle: 'Today, 10:30 AM',
            amount: '+\$45.00',
          ),
          const SizedBox(height: 12),
          _ActivityCard(
            title: 'Lac 2 → Airport (TUN)',
            subtitle: 'Today, 08:15 AM',
            amount: '+\$35.00',
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: onOpenActiveTrip,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Open active trip view',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Map-ready navigation structure and trip actions',
                          style: TextStyle(
                            color: Color(0xFF9A9A9A),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF7C7C7C)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlinePill extends StatelessWidget {
  final bool online;
  final ValueChanged<bool> onChanged;

  const _OnlinePill({
    required this.online,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!online),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: online ? const Color(0xFF18251C) : const Color(0xFF2A2222),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: online ? const Color(0x3351D37A) : const Color(0x334F4F4F),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.power_settings_new_rounded,
              color: online ? const Color(0xFF59D47B) : const Color(0xFFD36A6A),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              online ? 'Online' : 'Offline',
              style: TextStyle(
                color: online ? const Color(0xFF59D47B) : const Color(0xFFD36A6A),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF7F7F7F),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;

  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(Icons.location_on_outlined,
                color: Color(0xFF858585), size: 22),
          ),
          const SizedBox(width: 14),
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
                    color: Color(0xFF888888),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              color: Color(0xFF55D17A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
