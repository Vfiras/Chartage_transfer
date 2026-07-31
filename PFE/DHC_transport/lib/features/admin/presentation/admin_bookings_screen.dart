import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/admin_booking.dart';
import '../../../core/models/transport_trip.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/trip_service.dart';
import '../../../shared/widgets/admin/booking_card.dart';
import '../../../widgets/common/luxury_skeleton.dart';
import 'admin_booking_details_screen.dart';
import 'booking_edit_sheet.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final _service = const TripService();
  final _searchCtrl = TextEditingController();
  late Future<List<TransportTrip>> _future;
  bool _busy = false;

  // 'all' | 'pending_approval' (payment filter) | booking status values
  String _filter = 'all';
  String _query = '';

  static const _filters = <(String, String)>[
    ('all', 'admin_f_all'),
    ('pending_approval', 'admin_f_pending_approval'),
    ('pending', 'admin_st_pending'),
    ('confirmed', 'admin_st_confirmed'),
    ('on_route', 'admin_st_on_route'),
    ('completed', 'admin_st_completed'),
    ('cancelled', 'admin_st_cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _future = _service.listTrips();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _future = _service.listTrips();
      });

  List<TransportTrip> _applyFilter(List<TransportTrip> trips) {
    final byStatus = switch (_filter) {
      'all' => trips,
      'pending_approval' =>
        trips.where((t) => t.isPendingApproval).toList(growable: false),
      _ => trips.where((t) => t.status == _filter).toList(growable: false),
    };
    if (_query.isEmpty) return byStatus;
    // Client-side search over the already-loaded list — passenger or destination.
    final q = _query.toLowerCase();
    return byStatus
        .where((t) =>
            t.passengerName.toLowerCase().contains(q) ||
            t.destinationName.toLowerCase().contains(q) ||
            t.pickupLocation.toLowerCase().contains(q))
        .toList(growable: false);
  }

  // ── Details ─────────────────────────────────────────────────────────────────

  Future<void> _openDetails(TransportTrip trip) async {
    final didChange = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminBookingDetailsScreen(trip: trip),
      ),
    );
    if (didChange == true) _reload();
  }

  // ── Status update ────────────────────────────────────────────────────────────

  Future<void> _updateStatus(TransportTrip trip, String newStatus) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await _service.updateStatus(trip.id, newStatus);
      if (!mounted) return;
      _reload();
      _showSnackbar(_statusMessage(newStatus), success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Failed: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusMessage(String s) => switch (s) {
        'confirmed' => 'Booking confirmed',
        'cancelled' => 'Booking cancelled',
        'on_route' => 'Booking marked as on route',
        'completed' => 'Booking completed',
        _ => 'Status updated',
      };

  // ── Edit ─────────────────────────────────────────────────────────────────────

  Future<void> _edit(TransportTrip trip) async {
    if (_busy) return;
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingEditSheet(trip: trip),
    );
    if (payload == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.updateTrip(trip.id, payload);
      if (!mounted) return;
      _reload();
      _showSnackbar('Booking updated', success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Update failed: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────────

  Future<void> _delete(TransportTrip trip) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete booking?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This will permanently remove booking ${trip.id} from MongoDB.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.deleteBooking(trip.id);
      if (!mounted) return;
      _reload();
      _showSnackbar('Booking deleted', success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Delete failed: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnackbar(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          success ? const Color(0xFF1E3A1E) : const Color(0xFF3A1E1E),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    final l = LanguageService.instance;
    return SafeArea(
      child: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.secondary,
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
              children: [
                Text(
                  l.t('admin_bookings_title'),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.t('admin_bookings_subtitle'),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                // Client-side search over the loaded list.
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.softBorder),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AppColors.textMuted, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(Icons.close_rounded,
                                  color: AppColors.textMuted, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      hintText: l.t('admin_search_bookings'),
                      hintStyle: TextStyle(
                          color: AppColors.textHint, fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Status filter chips (incl. payment "Pending Approval")
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in _filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: l.t(f.$2),
                            selected: _filter == f.$1,
                            onTap: () => setState(() => _filter = f.$1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<TransportTrip>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // Card-shaped skeletons, not a spinner.
                      return const SkeletonCardList(
                        count: 4,
                        cardHeight: 128,
                        padding: EdgeInsets.zero,
                      );
                    }
                    if (snapshot.hasError) {
                      return _InfoCard(
                        icon: Icons.wifi_off_rounded,
                        title: l.t('admin_backend_unavailable'),
                        subtitle: snapshot.error.toString(),
                      );
                    }
                    final trips =
                        _applyFilter(snapshot.data ?? const <TransportTrip>[]);
                    if (trips.isEmpty) {
                      final filtered = _filter != 'all' || _query.isNotEmpty;
                      return _InfoCard(
                        icon: filtered
                            ? Icons.filter_alt_off_rounded
                            : Icons.receipt_long_outlined,
                        title: filtered
                            ? l.t('admin_no_match')
                            : l.t('admin_no_bookings'),
                        subtitle: filtered
                            ? l.t('admin_no_match_hint')
                            : l.t('admin_no_bookings_hint'),
                      );
                    }
                    return Column(
                      children: [
                        for (final trip in trips) ...[
                          BookingCard(
                            booking: AdminBooking.fromTrip(trip),
                            onViewDetails: () => _openDetails(trip),
                            onEdit: () => _edit(trip),
                            onDelete: () => _delete(trip),
                            onStatusChange: (s) => _updateStatus(trip, s),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

/// Pill filter chip matching the premium theme (gold fill when selected).
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondary
              : AppColors.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.secondary
                : AppColors.secondary.withValues(alpha: 0.32),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF221A08) : AppColors.secondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.secondary, size: 25),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
        ],
      ),
    );
  }
}
