import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/transport_api_client.dart';
import '../../../shared/widgets/admin/admin_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenFleet;
  final VoidCallback onOpenPromotions;
  final VoidCallback onOpenPricing;

  const AdminDashboardScreen({
    super.key,
    required this.onOpenBookings,
    required this.onOpenFleet,
    required this.onOpenPromotions,
    required this.onOpenPricing,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await TransportApiClient.instance.get('/admin/overview');
      if (!mounted) return;
      setState(() {
        _stats = (res['stats'] as Map?)?.cast<String, dynamic>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tileWidth = width > 700 ? (width - 68) / 4 : (width - 52) / 2;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.secondary,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
          children: [
            const _Header(),
            const SizedBox(height: 18),
            if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        color: AppColors.textMuted, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _load, child: Text('Retry')),
                  ],
                ),
              )
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatTile(
                    width: tileWidth,
                    label: 'Total bookings',
                    value: '${_stats?['total_bookings'] ?? 0}',
                    icon: Icons.receipt_long_rounded,
                  ),
                  _StatTile(
                    width: tileWidth,
                    label: 'Clients',
                    value: '${_stats?['total_users'] ?? 0}',
                    icon: Icons.people_rounded,
                  ),
                  _StatTile(
                    width: tileWidth,
                    label: 'Vehicles',
                    value: '${_stats?['total_cars'] ?? 0}',
                    icon: Icons.directions_car_rounded,
                  ),
                  _StatTile(
                    width: tileWidth,
                    label: 'Pending',
                    value: '${_stats?['pending_bookings'] ?? 0}',
                    icon: Icons.hourglass_empty_rounded,
                    accent: const Color(0xFFF59E0B),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AdminCard(
                label: 'Booking breakdown',
                value: 'Status overview',
                icon: Icons.bar_chart_rounded,
                child: _BookingBreakdown(stats: _stats ?? {}),
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
                      title: 'Bookings',
                      subtitle: 'Review, edit, or update booking status',
                      onTap: widget.onOpenBookings,
                    ),
                    const SizedBox(height: 10),
                    _ActionRow(
                      icon: Icons.directions_car_rounded,
                      title: 'Fleet management',
                      subtitle: 'Add, edit, or toggle car availability',
                      onTap: widget.onOpenFleet,
                    ),
                    const SizedBox(height: 10),
                    _ActionRow(
                      icon: Icons.local_offer_rounded,
                      title: 'Promotions',
                      subtitle: 'Manage promo codes and discounts',
                      onTap: widget.onOpenPromotions,
                    ),
                    const SizedBox(height: 10),
                    _ActionRow(
                      icon: Icons.tune_rounded,
                      title: 'Pricing rules',
                      subtitle: 'Configure night, weekend, and surge pricing',
                      onTap: widget.onOpenPricing,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Subwidgets ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin Dashboard',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Manage bookings, fleet, promotions, and pricing.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _StatTile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppColors.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AdminCard(
        label: label,
        value: value,
        icon: icon,
        accentColor: accent,
        compact: true,
      ),
    );
  }
}

class _BookingBreakdown extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _BookingBreakdown({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatusItem(
          'Pending', stats['pending_bookings'] ?? 0, const Color(0xFFF59E0B)),
      _StatusItem('Confirmed', stats['confirmed_bookings'] ?? 0,
          const Color(0xFF55A86B)),
      _StatusItem(
          'Completed', stats['completed_bookings'] ?? 0, AppColors.secondary),
      _StatusItem('Cancelled', stats['cancelled_bookings'] ?? 0,
          const Color(0xFFEF4444)),
    ];
    final total = items.fold<int>(0, (s, i) => s + i.count);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          for (final item in items) ...[
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  item.label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${item.count}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : item.count / total,
                backgroundColor: AppColors.surfaceElevated,
                valueColor: AlwaysStoppedAnimation<Color>(item.color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _StatusItem {
  final String label;
  final int count;
  final Color color;
  const _StatusItem(this.label, this.count, this.color);
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
      color: AppColors.surfaceElevated,
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
                  color: AppColors.secondary.withValues(alpha: 0.12),
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
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
