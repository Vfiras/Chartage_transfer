import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/transport_trip.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/transport_api_client.dart';
import '../../../core/services/trip_service.dart';
import '../../../shared/widgets/admin/admin_charts.dart';
import '../../../shared/widgets/admin/admin_top_bar.dart';
import '../../../widgets/common/luxury_skeleton.dart';

// ─── Local palette helpers ─────────────────────────────────────────────────────
// The design calls for a card that sits *above* the page and an inner tile that
// sits *below* it. AppColors' surface/surfaceElevated pair inverts that
// relationship between themes, so both tones are resolved per brightness here.

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Card surface — #1B1B1B on dark, near-white on ivory.
Color _card(BuildContext context) =>
    _isDark(context) ? const Color(0xFF1B1B1B) : const Color(0xFFFFFEFA);

/// Inner tile inside a card — recedes from the card in both themes.
Color _inner(BuildContext context) =>
    _isDark(context) ? const Color(0xFF141313) : const Color(0xFFF3ECDE);

Color _hairline(BuildContext context) =>
    _isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFE8DDCD);

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenFleet;
  final VoidCallback onOpenPromotions;
  final VoidCallback onOpenPricing;
  final VoidCallback? onOpenComplaints;
  final VoidCallback? onOpenSuppliers;
  final VoidCallback? onOpenRecommendations;
  final VoidCallback? onOpenNotifications;
  final int unreadCount;

  const AdminDashboardScreen({
    super.key,
    required this.onOpenBookings,
    required this.onOpenFleet,
    required this.onOpenPromotions,
    required this.onOpenPricing,
    this.onOpenComplaints,
    this.onOpenSuppliers,
    this.onOpenRecommendations,
    this.onOpenNotifications,
    this.unreadCount = 0,
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

  /// The header's menu opens the same secondary destinations as the quick
  /// actions grid, so the control is real rather than decorative.
  void _openMenu() {
    final l = LanguageService.instance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            for (final (icon, label, cb) in _secondaryDestinations(l))
              ListTile(
                leading: Icon(icon, color: AppColors.secondary, size: 21),
                title: Text(label,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600)),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted, size: 20),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  cb();
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// Screens that are not bottom-nav tabs. Bookings and Fleet are deliberately
  /// absent — they are tabs already, and duplicating them here was noise.
  List<(IconData, String, VoidCallback)> _secondaryDestinations(
      LanguageService l) {
    return [
      (Icons.campaign_rounded, l.t('admin_qa_promotions'),
          widget.onOpenPromotions),
      (Icons.euro_rounded, l.t('admin_qa_pricing'), widget.onOpenPricing),
      if (widget.onOpenComplaints != null)
        (Icons.report_problem_rounded, l.t('admin_qa_complaints'),
            widget.onOpenComplaints!),
      if (widget.onOpenSuppliers != null)
        (Icons.handshake_rounded, l.t('admin_qa_suppliers'),
            widget.onOpenSuppliers!),
      if (widget.onOpenRecommendations != null)
        (Icons.map_rounded, l.t('admin_qa_destinations'),
            widget.onOpenRecommendations!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(_isDark(context));
    final l = LanguageService.instance;

    return Column(
      children: [
        AdminTopBar(
          title: l.t('admin_dashboard_title'),
          unreadCount: widget.unreadCount,
          onNotificationTap: widget.onOpenNotifications,
          // The menu reaches the screens that are not nav tabs.
          action: IconButton(
            icon: Icon(Icons.menu_rounded,
                color: AppColors.secondary, size: 23),
            splashRadius: 22,
            onPressed: _openMenu,
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.secondary,
            backgroundColor: _card(context),
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
              children: [
                if (_loading)
                  const SkeletonCardList(
                    count: 4,
                    cardHeight: 120,
                    padding: EdgeInsets.zero,
                  )
                else if (_error != null)
                  _ErrorState(message: _error!, onRetry: _load)
                else ...[
                  // ── KPI rail ────────────────────────────────────────────
                  _KpiRail(
                    stats: _stats ?? const {},
                    analytics: _analytics,
                    trips: _trips,
                    onOpenFleet: widget.onOpenFleet,
                  ),

                  // ── Pending approvals (collapses when empty) ────────────
                  if (_pendingApprovals.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Icon(Icons.pending_actions_rounded,
                            color: AppColors.secondary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          l.t('admin_pending_approvals'),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PendingApprovalsRail(
                      bookings: _pendingApprovals,
                      onTapBooking: _openApprovalDetail,
                    ),
                  ],

                  // ── Booking trend ───────────────────────────────────────
                  const SizedBox(height: 26),
                  _SectionCard(
                    title: l.t('admin_booking_trend'),
                    child: _TrendChart(
                      perDay:
                          (_analytics?['bookings_per_day'] as List?) ?? const [],
                    ),
                  ),

                  // ── Job status ──────────────────────────────────────────
                  const SizedBox(height: 26),
                  _SectionCard(
                    title: l.t('admin_job_status'),
                    child: _JobStatusList(
                      stats: _stats ?? const {},
                      trips: _trips,
                    ),
                  ),

                  // ── Revenue split ───────────────────────────────────────
                  const SizedBox(height: 26),
                  _SectionCard(
                    title: l.t('admin_revenue_split'),
                    child: _RevenueSplit(analytics: _analytics),
                  ),

                  // ── Quick actions ───────────────────────────────────────
                  const SizedBox(height: 26),
                  _SectionCard(
                    title: l.t('admin_quick_actions'),
                    child: _QuickActionsGrid(
                      items: _secondaryDestinations(l),
                      openComplaints: _stats?['open_complaints'],
                      complaintsLabel: l.t('admin_qa_complaints'),
                    ),
                  ),

                  // ── Recent bookings ─────────────────────────────────────
                  const SizedBox(height: 26),
                  _SectionCard(
                    title: l.t('admin_recent_activity'),
                    action: _ViewAll(onTap: widget.onOpenBookings),
                    child: _RecentBookings(trips: _trips),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shared card shell ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;

  const _SectionCard({
    required this.title,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ViewAll extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewAll({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Text(
        LanguageService.instance.t('view_all'),
        style: TextStyle(
          color: AppColors.secondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── KPI rail ──────────────────────────────────────────────────────────────────

class _KpiRail extends StatelessWidget {
  final Map<String, dynamic> stats;
  final Map<String, dynamic>? analytics;
  final List<TransportTrip> trips;
  final VoidCallback onOpenFleet;

  const _KpiRail({
    required this.stats,
    required this.analytics,
    required this.trips,
    required this.onOpenFleet,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final revenue =
        ((analytics?['revenue'] as Map?)?['total'] as num?)?.toDouble();
    final completed = (stats['completed_bookings'] as num?)?.toInt() ?? 0;
    final pending = (stats['pending_bookings'] as num?)?.toInt() ?? 0;

    final cards = <_KpiData>[
      _KpiData(
        label: l.t('admin_kpi_revenue'),
        value: revenue == null ? '—' : _compact(revenue),
        suffix: revenue == null ? null : '€',
        gold: true,
        icon: Icons.account_balance_wallet_rounded,
        // Real caption — no invented growth percentage.
        caption: l.t('admin_from_completed', args: {'n': completed}),
      ),
      _KpiData(
        label: l.t('admin_kpi_bookings'),
        value: '${stats['total_bookings'] ?? 0}',
        icon: Icons.book_online_rounded,
        caption: l.t('admin_n_pending', args: {'n': pending}),
      ),
      _KpiData(
        label: l.t('admin_kpi_clients'),
        value: '${stats['total_users'] ?? 0}',
        icon: Icons.group_rounded,
        caption: l.t('admin_registered'),
      ),
      _KpiData(
        label: l.t('admin_kpi_fleet'),
        value: '${stats['total_cars'] ?? 0}',
        icon: Icons.directions_car_rounded,
        caption: l.t('admin_manage_fleet_cap'),
        onTap: onOpenFleet,
      ),
    ];

    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: EdgeInsets.zero,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _KpiCard(data: cards[i]),
      ),
    );
  }

  /// 142500 -> "142,500". Keeps the headline readable without scientific tricks.
  static String _compact(double v) =>
      NumberFormat.decimalPattern().format(v.round());
}

class _KpiData {
  final String label;
  final String value;
  final String? suffix;
  final String caption;
  final IconData icon;
  final bool gold;
  final VoidCallback? onTap;

  const _KpiData({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.suffix,
    this.gold = false,
    this.onTap,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 208,
        padding: const EdgeInsets.all(20),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: _card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hairline(context)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Oversized watermark icon bleeding off the top-right corner.
            Positioned(
              right: -30,
              top: -30,
              child: Icon(
                data.icon,
                size: 92,
                color: AppColors.secondary.withValues(alpha: 0.07),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        data.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: data.gold
                              ? AppColors.secondary
                              : AppColors.textPrimary,
                          fontSize: 30,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    if (data.suffix != null) ...[
                      const SizedBox(width: 3),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          data.suffix!,
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                Text(
                  data.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
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

// ─── Pending approvals rail ────────────────────────────────────────────────────

class _PendingApprovalsRail extends StatelessWidget {
  final List<TransportTrip> bookings;
  final ValueChanged<TransportTrip> onTapBooking;

  const _PendingApprovalsRail({
    required this.bookings,
    required this.onTapBooking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.30)),
      ),
      child: SizedBox(
        height: 186,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: bookings.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _PendingCard(
            trip: bookings[i],
            onTap: () => onTapBooking(bookings[i]),
          ),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final TransportTrip trip;
  final VoidCallback onTap;

  const _PendingCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return Container(
      width: 252,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trip.pickupLocation} → ${trip.destinationName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${trip.totalPrice.toStringAsFixed(0)} €',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_month_rounded,
                  size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                trip.departureDate,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _inner(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car_rounded,
                      size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    trip.vehicleClass,
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 38,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: const Color(0xFF221A08),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                l.t('admin_approve').toUpperCase(),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Booking trend chart ───────────────────────────────────────────────────────

class _TrendChart extends StatelessWidget {
  final List perDay;

  const _TrendChart({required this.perDay});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final data = perDay
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    if (data.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            l.t('admin_no_chart_data'),
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    // Shared primitive — identical styling to AVA's analytics charts.
    return SizedBox(
      height: 200,
      child: GoldBarChart(
        points: [
          for (final e in data)
            ChartPoint(e['date']?.toString() ?? '',
                ((e['count'] as num?) ?? 0).toDouble()),
        ],
        showLeftAxis: false,
        barWidth: 18,
        labelFormat: _weekday,
      ),
    );
  }

  /// 'YYYY-MM-DD' -> 'MON'. Falls back to the day number if unparseable.
  static String _weekday(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) {
      return date.length >= 10 ? date.substring(8, 10) : date;
    }
    return DateFormat('E').format(parsed).toUpperCase();
  }
}

// ─── Job status ────────────────────────────────────────────────────────────────

class _JobStatusList extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<TransportTrip> trips;

  const _JobStatusList({required this.stats, required this.trips});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    // on_route isn't in /admin/overview; derive it from the loaded bookings.
    final onRoute = trips.where((t) => t.status == 'on_route').length;

    final rows = <(String, int, Color, bool)>[
      (
        l.t('admin_st_pending'),
        (stats['pending_bookings'] as num?)?.toInt() ?? 0,
        const Color(0xFFF59E0B),
        false
      ),
      (
        l.t('admin_st_confirmed'),
        (stats['confirmed_bookings'] as num?)?.toInt() ?? 0,
        const Color(0xFF10B981),
        true // highlighted with a gold rail, as in the design
      ),
      (l.t('admin_st_on_route'), onRoute, const Color(0xFF3B82F6), false),
      (
        l.t('admin_st_completed'),
        (stats['completed_bookings'] as num?)?.toInt() ?? 0,
        const Color(0xFF14B8A6),
        false
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _JobStatusRow(
            label: rows[i].$1,
            count: rows[i].$2,
            dot: rows[i].$3,
            highlighted: rows[i].$4,
          ),
        ],
      ],
    );
  }
}

class _JobStatusRow extends StatelessWidget {
  final String label;
  final int count;
  final Color dot;
  final bool highlighted;

  const _JobStatusRow({
    required this.label,
    required this.count,
    required this.dot,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _inner(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Gold rail on the highlighted row — drawn as a sliver because a
          // left-only border cannot be combined with a borderRadius.
          Container(
            width: 2,
            height: 42,
            color: highlighted ? AppColors.secondary : Colors.transparent,
          ),
          const SizedBox(width: 12),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Text(
              '$count',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Revenue split ─────────────────────────────────────────────────────────────

class _RevenueSplit extends StatelessWidget {
  final Map<String, dynamic>? analytics;

  const _RevenueSplit({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final byCat = (((analytics?['revenue'] as Map?)?['by_category'] as List?) ??
            const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final total = byCat.fold<double>(
        0, (s, e) => s + ((e['revenue'] as num?)?.toDouble() ?? 0));

    if (byCat.isEmpty || total <= 0) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            l.t('admin_no_revenue_yet'),
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    // Shared primitive — identical styling to AVA's analytics charts.
    return SizedBox(
      height: 210,
      child: GoldPieChart(
        points: [
          for (final e in byCat)
            ChartPoint(e['category']?.toString() ?? '—',
                ((e['revenue'] as num?) ?? 0).toDouble()),
        ],
        legend: PieLegend.below,
        // Donut hole punched in the card colour, matching the design.
        holeColor: _card(context),
        showPercentages: false,
      ),
    );
  }
}

// ─── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final List<(IconData, String, VoidCallback)> items;
  final dynamic openComplaints;
  final String complaintsLabel;

  const _QuickActionsGrid({
    required this.items,
    required this.openComplaints,
    required this.complaintsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final openCount = (openComplaints as num?)?.toInt() ?? 0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final (icon, label, onTap) = items[i];
        final badge = label == complaintsLabel && openCount > 0
            ? '$openCount'
            : null;
        return _QuickActionCard(
          icon: icon,
          label: label,
          badge: badge,
          onTap: onTap,
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _inner(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hairline(context)),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.secondary, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Recent bookings ───────────────────────────────────────────────────────────

class _RecentBookings extends StatelessWidget {
  final List<TransportTrip> trips;

  const _RecentBookings({required this.trips});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final shown = trips.take(4).toList();

    if (shown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          l.t('admin_no_bookings'),
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < shown.length; i++)
          _RecentBookingTile(
            trip: shown[i],
            showDivider: i < shown.length - 1,
          ),
      ],
    );
  }
}

class _RecentBookingTile extends StatelessWidget {
  final TransportTrip trip;
  final bool showDivider;

  const _RecentBookingTile({required this.trip, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusStyle(trip.status);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: _hairline(context))),
            )
          : null,
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${trip.pickupLocation} → ${trip.destinationName} • '
                  '${trip.departureDate} ${trip.departureTime}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.32)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) _statusStyle(String status) {
    final l = LanguageService.instance;
    return switch (status) {
      'pending' => (const Color(0xFFF59E0B), l.t('admin_st_pending')),
      'confirmed' => (const Color(0xFF10B981), l.t('admin_st_confirmed')),
      'on_route' => (const Color(0xFF3B82F6), l.t('admin_st_on_route')),
      'completed' => (const Color(0xFF14B8A6), l.t('admin_st_completed')),
      'cancelled' => (AppColors.danger, l.t('admin_st_cancelled')),
      _ => (AppColors.textMuted, status),
    };
  }
}

// ─── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(LanguageService.instance.t('admin_retry')),
          ),
        ],
      ),
    );
  }
}

// ─── Approval detail sheet ─────────────────────────────────────────────────────

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
