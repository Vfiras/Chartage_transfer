import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/transport_trip.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/transport_api_client.dart';
import '../../../core/services/trip_service.dart';
import '../../../widgets/common/luxury_skeleton.dart';

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenFleet;
  final VoidCallback onOpenPromotions;
  final VoidCallback onOpenPricing;
  final VoidCallback? onOpenComplaints;
  final VoidCallback? onOpenSuppliers;
  final VoidCallback? onOpenRecommendations;

  const AdminDashboardScreen({
    super.key,
    required this.onOpenBookings,
    required this.onOpenFleet,
    required this.onOpenPromotions,
    required this.onOpenPricing,
    this.onOpenComplaints,
    this.onOpenSuppliers,
    this.onOpenRecommendations,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _analytics; // GET /analytics/dashboard (best-effort)
  List<TransportTrip> _trips = [];
  bool _loading = true;
  bool _approving = false;
  String? _error;

  List<TransportTrip> get _pendingApprovals =>
      _trips.where((t) => t.isPendingApproval).toList();

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
      // Analytics is best-effort: if it fails, the overview still renders so
      // the screen never breaks just because the richer endpoint hiccuped.
      Map<String, dynamic>? analytics;
      try {
        final a = await TransportApiClient.instance.get('/analytics/dashboard');
        analytics = (a as Map?)?.cast<String, dynamic>();
      } catch (_) {
        analytics = null;
      }
      // Full booking list — feeds pending approvals, the on-route count, and
      // the recent-activity list. Best-effort too.
      List<TransportTrip> trips = [];
      try {
        trips = await const TripService().listTrips();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _stats = (res['stats'] as Map?)?.cast<String, dynamic>();
        _analytics = analytics;
        _trips = trips;
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

  Future<void> _approve(TransportTrip trip) async {
    if (_approving) return;
    setState(() => _approving = true);
    try {
      await const TripService().approvePayment(trip.id);
      if (!mounted) return;
      Navigator.of(context).maybePop(); // close the detail sheet
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Booking for ${trip.passengerName} approved ✓'),
        backgroundColor: const Color(0xFF1E3A1E),
        behavior: SnackBarBehavior.floating,
      ));
      await _load(); // card disappears from the pending list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Approval failed: $e'),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  void _openApprovalDetail(TransportTrip trip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ApprovalDetailSheet(
        trip: trip,
        onApprove: () => _approve(trip),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    final l = LanguageService.instance;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.secondary,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
          children: [
            // Not const: a const instance is canonicalised, so Flutter skips
            // rebuilding it when the theme/language notifier fires — the title
            // would keep dark-mode colours and English text on a light, FR UI.
            _Header(),
            const SizedBox(height: 18),
            if (_loading)
              const SkeletonCardList(
                count: 4,
                cardHeight: 120,
                padding: EdgeInsets.zero,
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
                    TextButton(
                        onPressed: _load, child: Text(l.t('admin_retry'))),
                  ],
                ),
              )
            else ...[
              // ── 1 · Key metrics ─────────────────────────────────────────
              _SectionTitle(l.t('admin_key_metrics')),
              const SizedBox(height: 10),
              _KpiRow(stats: _stats ?? {}, analytics: _analytics),
              const SizedBox(height: 22),

              // ── 2 · Pending cash approvals (collapses when empty) ──────
              if (_pendingApprovals.isNotEmpty) ...[
                _PendingApprovalsSection(
                  bookings: _pendingApprovals,
                  onTapBooking: _openApprovalDetail,
                ),
                const SizedBox(height: 22),
              ],

              // ── 3 · Charts ─────────────────────────────────────────────
              if (_analytics != null) ...[
                _SectionTitle(l.t('admin_booking_trend')),
                const SizedBox(height: 10),
                _TrendBarCard(
                  perDay: (_analytics!['bookings_per_day'] as List?) ??
                      const [],
                ),
                const SizedBox(height: 22),
                _SectionTitle(l.t('admin_revenue_by_category')),
                const SizedBox(height: 10),
                _RevenuePieCard(analytics: _analytics!),
                const SizedBox(height: 22),
              ],

              // ── 4 · Status breakdown ───────────────────────────────────
              _SectionTitle(l.t('admin_status_breakdown')),
              const SizedBox(height: 10),
              _StatusChipsRow(stats: _stats ?? {}, trips: _trips),
              const SizedBox(height: 22),

              // ── 5 · Quick actions ──────────────────────────────────────
              _SectionTitle(l.t('admin_quick_actions')),
              const SizedBox(height: 10),
              _QuickActionsGrid(
                openComplaints: _stats?['open_complaints'],
                onOpenBookings: widget.onOpenBookings,
                onOpenFleet: widget.onOpenFleet,
                onOpenPromotions: widget.onOpenPromotions,
                onOpenPricing: widget.onOpenPricing,
                onOpenComplaints: widget.onOpenComplaints,
                onOpenSuppliers: widget.onOpenSuppliers,
                onOpenRecommendations: widget.onOpenRecommendations,
              ),

              // ── 6 · Recent activity ────────────────────────────────────
              if (_trips.isNotEmpty) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                        child: _SectionTitle(l.t('admin_recent_activity'))),
                    GestureDetector(
                      onTap: widget.onOpenBookings,
                      child: Row(
                        children: [
                          Text(
                            l.t('view_all'),
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_rounded,
                              size: 13, color: AppColors.secondary),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final trip in _trips.take(5)) ...[
                  _RecentBookingRow(trip: trip),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Section title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: AppColors.secondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.t('admin_dashboard_title'),
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l.t('admin_dashboard_subtitle'),
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ─── 1 · KPI row ───────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  final Map<String, dynamic>? analytics;

  const _KpiRow({required this.stats, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final revenue =
        ((analytics?['revenue'] as Map?)?['total'] as num?)?.toDouble();

    final cards = [
      (
        l.t('admin_kpi_revenue'),
        revenue == null ? '—' : '${revenue.toStringAsFixed(0)} EUR',
        Icons.payments_rounded,
      ),
      (
        l.t('admin_kpi_bookings'),
        '${stats['total_bookings'] ?? 0}',
        Icons.receipt_long_rounded,
      ),
      (
        l.t('admin_kpi_clients'),
        '${stats['total_users'] ?? 0}',
        Icons.people_rounded,
      ),
      (
        l.t('admin_kpi_fleet'),
        '${stats['total_cars'] ?? 0}',
        Icons.directions_car_rounded,
      ),
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (label, value, icon) = cards[i];
          return Container(
            width: 156,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.softBorder),
              // Signature gold top edge.
              boxShadow: const [],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(
                top: BorderSide(
                  color: AppColors.secondary.withValues(alpha: 0.65),
                  width: 2,
                ),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 4,
                  child: Icon(
                    icon,
                    size: 26,
                    color: AppColors.secondary.withValues(alpha: 0.25),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── 3a · 7-day trend (fl_chart bar) ───────────────────────────────────────────

class _TrendBarCard extends StatelessWidget {
  final List perDay;

  const _TrendBarCard({required this.perDay});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final data = perDay
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    if (data.isEmpty) {
      return _ChartCard(
        child: SizedBox(
          height: 60,
          child: Center(
            child: Text(
              l.t('admin_no_chart_data'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ),
      );
    }

    final maxCount = data.fold<double>(
      1,
      (m, e) {
        final c = ((e['count'] as num?) ?? 0).toDouble();
        return c > m ? c : m;
      },
    );

    return _ChartCard(
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxCount * 1.25,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxCount / 3).clamp(1, double.infinity),
              getDrawingHorizontalLine: (_) => FlLine(
                color: AppColors.softBorder,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  interval: (maxCount / 3).clamp(1, double.infinity),
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox();
                    final date = data[i]['date']?.toString() ?? '';
                    final day =
                        date.length >= 10 ? date.substring(8, 10) : date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        day,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  '${data[group.x]['date'] ?? ''}\n${rod.toY.toInt()}',
                  const TextStyle(
                    color: Color(0xFFFFFCF3),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: ((data[i]['count'] as num?) ?? 0).toDouble(),
                      width: 14,
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xFF8E7745), Color(0xFFC8A96B)],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 3b · Revenue by category (fl_chart pie) ───────────────────────────────────

class _RevenuePieCard extends StatelessWidget {
  final Map<String, dynamic> analytics;

  const _RevenuePieCard({required this.analytics});

  static const _palette = [
    AppColors.secondary,
    AppColors.teal,
    Color(0xFFF59E0B),
    AppColors.blue,
    AppColors.purple,
    AppColors.green,
  ];

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final byCat = (((analytics['revenue'] as Map?)?['by_category'] as List?) ??
            const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final total = byCat.fold<double>(
        0, (s, e) => s + ((e['revenue'] as num?)?.toDouble() ?? 0));

    if (byCat.isEmpty || total <= 0) {
      return _ChartCard(
        child: SizedBox(
          height: 60,
          child: Center(
            child: Text(
              l.t('admin_no_revenue_yet'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return _ChartCard(
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 36,
                sections: [
                  for (var i = 0; i < byCat.length; i++)
                    PieChartSectionData(
                      value:
                          ((byCat[i]['revenue'] as num?) ?? 0).toDouble(),
                      color: _palette[i % _palette.length],
                      radius: 42,
                      showTitle: true,
                      title:
                          '${((((byCat[i]['revenue'] as num?) ?? 0).toDouble()) / total * 100).round()}%',
                      titleStyle: const TextStyle(
                        color: Color(0xFF15120D),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (var i = 0; i < byCat.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _palette[i % _palette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${byCat[i]['category'] ?? '—'} · ${((byCat[i]['revenue'] as num?) ?? 0).toStringAsFixed(0)} EUR',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;

  const _ChartCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: child,
    );
  }
}

// ─── 4 · Status breakdown chips ────────────────────────────────────────────────

class _StatusChipsRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<TransportTrip> trips;

  const _StatusChipsRow({required this.stats, required this.trips});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    // on_route isn't in /admin/overview; derive it from the loaded bookings.
    final onRoute = trips.where((t) => t.status == 'on_route').length;

    final chips = [
      (l.t('admin_st_pending'), stats['pending_bookings'] ?? 0,
          const Color(0xFFF59E0B)),
      (l.t('admin_st_confirmed'), stats['confirmed_bookings'] ?? 0,
          AppColors.green),
      (l.t('admin_st_on_route'), onRoute, AppColors.blue),
      (l.t('admin_st_completed'), stats['completed_bookings'] ?? 0,
          AppColors.teal),
      (l.t('admin_st_cancelled'), stats['cancelled_bookings'] ?? 0,
          AppColors.danger),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, count, color) in chips)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── 5 · Quick actions grid ────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final dynamic openComplaints;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenFleet;
  final VoidCallback onOpenPromotions;
  final VoidCallback onOpenPricing;
  final VoidCallback? onOpenComplaints;
  final VoidCallback? onOpenSuppliers;
  final VoidCallback? onOpenRecommendations;

  const _QuickActionsGrid({
    required this.openComplaints,
    required this.onOpenBookings,
    required this.onOpenFleet,
    required this.onOpenPromotions,
    required this.onOpenPricing,
    this.onOpenComplaints,
    this.onOpenSuppliers,
    this.onOpenRecommendations,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final actions = <(IconData, String, String?, VoidCallback)>[
      (Icons.receipt_long_rounded, l.t('admin_qa_bookings'), null,
          onOpenBookings),
      (Icons.directions_car_rounded, l.t('admin_qa_fleet'), null, onOpenFleet),
      (Icons.local_offer_rounded, l.t('admin_qa_promotions'), null,
          onOpenPromotions),
      (Icons.tune_rounded, l.t('admin_qa_pricing'), null, onOpenPricing),
      if (onOpenComplaints != null)
        (
          Icons.feedback_rounded,
          l.t('admin_qa_complaints'),
          '${openComplaints ?? 0}',
          onOpenComplaints!,
        ),
      if (onOpenSuppliers != null)
        (Icons.handshake_rounded, l.t('admin_qa_suppliers'), null,
            onOpenSuppliers!),
      if (onOpenRecommendations != null)
        (Icons.place_rounded, l.t('admin_qa_destinations'), null,
            onOpenRecommendations!),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      itemCount: actions.length,
      itemBuilder: (_, i) {
        final (icon, label, badge, onTap) = actions[i];
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.softBorder),
              ),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.secondary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (badge != null && badge != '0')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── 6 · Recent activity ───────────────────────────────────────────────────────

class _RecentBookingRow extends StatelessWidget {
  final TransportTrip trip;

  const _RecentBookingRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(trip.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.passengerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${trip.pickupLocation} → ${trip.destinationName} · ${trip.departureDate}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trip.status.replaceAll('_', ' '),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    'pending' => const Color(0xFFF59E0B),
    'confirmed' => AppColors.green,
    'on_route' => AppColors.blue,
    'completed' => AppColors.teal,
    'cancelled' => AppColors.danger,
    _ => AppColors.textMuted,
  };
}

// ─── Pending cash approvals (kept from the previous design) ────────────────────

class _PendingApprovalsSection extends StatelessWidget {
  final List<TransportTrip> bookings;
  final ValueChanged<TransportTrip> onTapBooking;

  const _PendingApprovalsSection({
    required this.bookings,
    required this.onTapBooking,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(Icons.pending_actions_rounded,
                    color: AppColors.secondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.t('admin_pending_approvals'),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${bookings.length}',
                    style: const TextStyle(
                      color: Color(0xFF221A08),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.t('admin_pending_approvals_subtitle'),
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _PendingBookingCard(
                trip: bookings[i],
                onTap: () => onTapBooking(bookings[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingBookingCard extends StatelessWidget {
  final TransportTrip trip;
  final VoidCallback onTap;

  const _PendingBookingCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trip.passengerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${trip.pickupLocation} → ${trip.destinationName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${trip.departureDate} · ${trip.vehicleClass}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ),
                Text(
                  '${trip.totalPrice.toStringAsFixed(0)} EUR',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalDetailSheet extends StatelessWidget {
  final TransportTrip trip;
  final VoidCallback onApprove;

  const _ApprovalDetailSheet({required this.trip, required this.onApprove});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(label,
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: Text(value,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.t('admin_booking_approval'),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.chipGoldBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'CASH · PENDING',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          row(l.t('admin_client'), trip.passengerName),
          row(l.t('admin_route'),
              '${trip.pickupLocation} → ${trip.destinationName}'),
          row(l.t('date'), '${trip.departureDate} ${trip.departureTime}'),
          row(l.t('admin_vehicle'), trip.vehicleClass),
          row(l.t('admin_total'),
              '${trip.totalPrice.toStringAsFixed(2)} EUR'),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: const Color(0xFF221A08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              label: Text(
                l.t('admin_approve_booking'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
