import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/transport_trip.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/trip_service.dart';
import '../../../shared/widgets/admin/admin_top_bar.dart';
import '../../../widgets/common/luxury_skeleton.dart';
import 'admin_booking_details_screen.dart';
import 'booking_edit_sheet.dart';

// ─── Local palette helpers (mirrors the dashboard) ─────────────────────────────

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _card(BuildContext context) =>
    _isDark(context) ? const Color(0xFF1B1B1B) : const Color(0xFFFFFEFA);

Color _inner(BuildContext context) =>
    _isDark(context) ? const Color(0xFF141313) : const Color(0xFFF3ECDE);

Color _hairline(BuildContext context) =>
    _isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFE8DDCD);

class AdminBookingsScreen extends StatefulWidget {
  final int unreadCount;
  final VoidCallback? onOpenNotifications;

  const AdminBookingsScreen({
    super.key,
    this.unreadCount = 0,
    this.onOpenNotifications,
  });

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
    final l = LanguageService.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.t('admin_delete_booking'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Text(
          l.t('admin_delete_booking_confirm'),
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                Text(l.t('cancel'), style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.t('delete')),
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
    AppColors.setDarkMode(_isDark(context));
    final l = LanguageService.instance;

    return Stack(
      children: [
        Column(
          children: [
            AdminTopBar(
              title: l.t('admin_bookings_title'),
              unreadCount: widget.unreadCount,
              onNotificationTap: widget.onOpenNotifications,
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.secondary,
                backgroundColor: _card(context),
                onRefresh: () async => _reload(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 130),
                  children: [
                    // ── Page heading ─────────────────────────────────────
                    Text(
                      l.t('admin_bookings_title'),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.t('admin_bookings_subtitle'),
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Search ───────────────────────────────────────────
                    _SearchField(
                      controller: _searchCtrl,
                      query: _query,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      onClear: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Filter pills ─────────────────────────────────────
                    _FilterPills(
                      filters: _filters,
                      selected: _filter,
                      onSelect: (v) => setState(() => _filter = v),
                    ),
                    const SizedBox(height: 20),

                    // ── List ─────────────────────────────────────────────
                    FutureBuilder<List<TransportTrip>>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SkeletonCardList(
                            count: 3,
                            cardHeight: 210,
                            padding: EdgeInsets.zero,
                          );
                        }
                        if (snapshot.hasError) {
                          return _EmptyState(
                            icon: Icons.wifi_off_rounded,
                            title: l.t('admin_backend_unavailable'),
                            subtitle: snapshot.error.toString(),
                          );
                        }
                        final trips = _applyFilter(
                            snapshot.data ?? const <TransportTrip>[]);
                        if (trips.isEmpty) {
                          final filtered =
                              _filter != 'all' || _query.isNotEmpty;
                          return _EmptyState(
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
                              _BookingCard(
                                trip: trip,
                                onDetails: () => _openDetails(trip),
                                onEdit: () => _edit(trip),
                                onDelete: () => _delete(trip),
                                onApprove: () =>
                                    _updateStatus(trip, 'confirmed'),
                                onReject: () =>
                                    _updateStatus(trip, 'cancelled'),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    );
  }
}

// ─── Search ────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _inner(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline(context)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 15),
          prefixIcon:
              Icon(Icons.search_rounded, color: AppColors.textMuted, size: 21),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 18),
                  onPressed: onClear,
                ),
          hintText: LanguageService.instance.t('admin_search_bookings'),
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
        ),
      ),
    );
  }
}

// ─── Filter pills ──────────────────────────────────────────────────────────────

class _FilterPills extends StatelessWidget {
  final List<(String, String)> filters;
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterPills({
    required this.filters,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (value, labelKey) = filters[i];
          final active = selected == value;
          return GestureDetector(
            onTap: () => onSelect(value),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: active ? AppColors.secondary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active
                      ? AppColors.secondary
                      : (_isDark(context)
                          ? const Color(0xFF4D463A)
                          : const Color(0xFFE8DDCD)),
                ),
              ),
              child: Text(
                l.t(labelKey),
                style: TextStyle(
                  color: active
                      ? const Color(0xFF402D00)
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final TransportTrip trip;

  const _StatusChip({required this.trip});

  /// Pending-approval is a *payment* state and outranks the booking status in
  /// the chip, because it is the one that needs an admin decision.
  static (Color, String) styleFor(TransportTrip trip) {
    final l = LanguageService.instance;
    if (trip.isPendingApproval) {
      return (AppColors.secondary, l.t('admin_f_pending_approval'));
    }
    return switch (trip.status) {
      'pending' => (const Color(0xFFF59E0B), l.t('admin_st_pending')),
      'confirmed' => (const Color(0xFF10B981), l.t('admin_st_confirmed')),
      'on_route' => (const Color(0xFF3B82F6), l.t('admin_st_on_route')),
      'completed' => (const Color(0xFF14B8A6), l.t('admin_st_completed')),
      'cancelled' => (const Color(0xFFE07A7A), l.t('admin_st_cancelled')),
      _ => (AppColors.textMuted, trip.status),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (color, label) = styleFor(trip);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─── Booking card ──────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final TransportTrip trip;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _BookingCard({
    required this.trip,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final awaiting = trip.isPendingApproval;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: _card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline(context)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gold accent rail — marks the cards that need a decision.
            Container(
              width: 4,
              color: awaiting ? AppColors.secondary : Colors.transparent,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: icon, reference, price ──────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _inner(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            awaiting
                                ? Icons.receipt_long_rounded
                                : Icons.directions_car_rounded,
                            color: AppColors.secondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.id.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${trip.totalPrice.toStringAsFixed(2)} EUR',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 26,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                trip.vehicleClass,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Pickup date/time ────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 66,
                          child: Text(
                            l.t('admin_lbl_pickup'),
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${trip.departureDate} ${trip.departureTime}',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Route ───────────────────────────────────────────
                    _RouteBox(
                      from: trip.pickupLocation,
                      to: trip.destinationName,
                    ),
                    const SizedBox(height: 14),

                    // ── Client ──────────────────────────────────────────
                    _LabeledRow(
                      label: l.t('admin_client').toUpperCase(),
                      value: trip.passengerName,
                    ),
                    if (trip.passengerPhone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _LabeledRow(
                        label: l.t('admin_lbl_phone'),
                        value: trip.passengerPhone,
                      ),
                    ],
                    const SizedBox(height: 14),

                    // ── Status ──────────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _StatusChip(trip: trip),
                    ),
                    const SizedBox(height: 16),

                    // ── Actions ─────────────────────────────────────────
                    if (awaiting) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _CardButton(
                              icon: Icons.check_circle_outline_rounded,
                              label: l.t('admin_approve'),
                              tone: _ButtonTone.gold,
                              onTap: onApprove,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CardButton(
                              icon: Icons.cancel_outlined,
                              label: l.t('admin_reject'),
                              tone: _ButtonTone.danger,
                              onTap: onReject,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Divider(color: _hairline(context), height: 18),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _CardButton(
                            icon: Icons.visibility_outlined,
                            label: l.t('admin_details'),
                            tone: _ButtonTone.filled,
                            onTap: onDetails,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CardButton(
                            icon: Icons.edit_outlined,
                            label: l.t('admin_edit'),
                            tone: _ButtonTone.outline,
                            onTap: onEdit,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _CardButton(
                      icon: Icons.delete_outline_rounded,
                      label: l.t('delete'),
                      tone: _ButtonTone.danger,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pickup → destination with a connector line, as on the detail screen.
class _RouteBox extends StatelessWidget {
  final String from;
  final String to;

  const _RouteBox({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _inner(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _hairline(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dots + connector.
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34D399),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 2,
                  height: 24,
                  color: _hairline(context),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  from,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  to,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.5,
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

class _LabeledRow extends StatelessWidget {
  final String label;
  final String value;

  const _LabeledRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 66,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

enum _ButtonTone { filled, outline, gold, danger }

class _CardButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final _ButtonTone tone;
  final VoidCallback onTap;

  const _CardButton({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFE07A7A);
    final (bg, fg, border) = switch (tone) {
      _ButtonTone.filled => (
          AppColors.secondary,
          const Color(0xFF402D00),
          AppColors.secondary,
        ),
      _ButtonTone.gold => (
          AppColors.secondary.withValues(alpha: 0.10),
          AppColors.secondary,
          AppColors.secondary.withValues(alpha: 0.35),
        ),
      _ButtonTone.danger => (
          danger.withValues(alpha: 0.10),
          danger,
          danger.withValues(alpha: 0.30),
        ),
      _ButtonTone.outline => (
          Colors.transparent,
          AppColors.textSecondary,
          _hairline(context),
        ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
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

// ─── Empty / error state ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: _card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline(context)),
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
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
