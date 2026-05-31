import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/admin_booking.dart';
import '../../../core/models/transport_trip.dart';
import '../../../core/services/trip_service.dart';
import '../../../shared/widgets/admin/booking_card.dart';
import 'admin_booking_details_screen.dart';
import 'booking_edit_sheet.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  final _service = const TripService();
  late Future<List<TransportTrip>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _service.listTrips();
  }

  void _reload() => setState(() => _future = _service.listTrips());

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
                  'Bookings',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage trips, update statuses, and edit booking records.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<TransportTrip>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.secondary),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return _InfoCard(
                        title: 'Backend unavailable',
                        subtitle: snapshot.error.toString(),
                      );
                    }
                    final trips =
                        snapshot.data ?? const <TransportTrip>[];
                    if (trips.isEmpty) {
                      return const _InfoCard(
                        title: 'No bookings yet',
                        subtitle:
                            'Bookings created by clients will appear here.',
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

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _InfoCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
