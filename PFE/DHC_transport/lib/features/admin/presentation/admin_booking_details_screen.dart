import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/admin_booking.dart';
import '../../../core/models/transport_trip.dart';
import '../../../core/services/trip_service.dart';
import 'booking_edit_sheet.dart';

class AdminBookingDetailsScreen extends StatefulWidget {
  final TransportTrip trip;

  const AdminBookingDetailsScreen({super.key, required this.trip});

  @override
  State<AdminBookingDetailsScreen> createState() =>
      _AdminBookingDetailsScreenState();
}

class _AdminBookingDetailsScreenState
    extends State<AdminBookingDetailsScreen> {
  late AdminBooking _booking;
  late TransportTrip _trip;
  bool _busy = false;
  bool _didChange = false;

  final _service = const TripService();

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _booking = AdminBooking.fromTrip(_trip);
  }

  // ── Status update ───────────────────────────────────────────────────────────

  Future<void> _updateStatus(AdminBookingStatus newStatus) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    final prev = _booking;
    setState(() {
      _booking = _booking.copyWithStatus(newStatus);
      _busy = true;
    });
    try {
      await _service.updateStatus(_trip.id, newStatus.rawValue);
      if (!mounted) return;
      _didChange = true;
      _showSnackbar(_statusMessage(newStatus), success: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _booking = prev);
      _showSnackbar('Failed: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusMessage(AdminBookingStatus s) => switch (s) {
        AdminBookingStatus.confirmed => 'Booking confirmed',
        AdminBookingStatus.cancelled => 'Booking cancelled',
        AdminBookingStatus.onRoute => 'Booking marked as on route',
        AdminBookingStatus.completed => 'Booking completed',
        _ => 'Status updated',
      };

  // ── Edit ────────────────────────────────────────────────────────────────────

  Future<void> _edit() async {
    if (_busy) return;
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingEditSheet(trip: _trip),
    );
    if (payload == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await _service.updateTrip(_trip.id, payload);
      if (!mounted) return;
      setState(() {
        _trip = updated;
        _booking = AdminBooking.fromTrip(updated);
      });
      _didChange = true;
      _showSnackbar('Booking updated successfully', success: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Update failed: ${e.toString()}', success: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnackbar(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success
          ? const Color(0xFF1E3A1E)
          : const Color(0xFF3A1E1E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final b = _booking;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        // Signal the bookings list to refresh if anything changed
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(_didChange),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking Details',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              Text(b.reference,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.edit_outlined, color: AppColors.secondary),
              tooltip: 'Edit booking',
              onPressed: _edit,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                // ── Status badge ──────────────────────────────────────────
                _StatusBadge(status: b.status),
                const SizedBox(height: 20),

                // ── Route card ────────────────────────────────────────────
                _SectionCard(
                  title: 'Route',
                  icon: Icons.route_rounded,
                  children: [
                    _RouteVisual(source: b.source, destination: b.destination),
                    const SizedBox(height: 12),
                    _DetailRow('Date', b.departureDate.isNotEmpty ? b.departureDate : '—'),
                    _DetailRow('Time', b.departureTime.isNotEmpty ? b.departureTime : '—'),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Client card ───────────────────────────────────────────
                _SectionCard(
                  title: 'Client',
                  icon: Icons.person_outline_rounded,
                  children: [
                    _DetailRow('Name', b.clientName),
                    _DetailRow('Phone', b.clientPhone.isNotEmpty ? b.clientPhone : '—'),
                    if (b.contactEmail.isNotEmpty)
                      _DetailRow('Email', b.contactEmail),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Trip details card ─────────────────────────────────────
                _SectionCard(
                  title: 'Trip Details',
                  icon: Icons.local_taxi_outlined,
                  children: [
                    _DetailRow('Vehicle', b.vehicleType.isNotEmpty ? b.vehicleType : '—'),
                    _DetailRow('Passengers', b.passengerCount.toString()),
                    _DetailRow('Luggage', b.luggageCount.toString()),
                    _DetailRow('Price', b.price),
                    _DetailRow('Supplier', b.supplierName),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Quick status actions ──────────────────────────────────
                if (b.status != AdminBookingStatus.completed &&
                    b.status != AdminBookingStatus.cancelled) ...[
                  Text(
                    'QUICK ACTIONS',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _QuickActionPanel(
                    status: b.status,
                    onStatusChange: (s) => _updateStatus(
                      AdminBookingStatusX.fromRaw(s),
                    ),
                  ),
                ],
              ],
            ),

            // Loading overlay
            if (_busy)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final AdminBookingStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
              color: status.color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.icon, required this.children});

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
          Row(
            children: [
              Icon(icon, color: AppColors.secondary, size: 18),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Route visual ──────────────────────────────────────────────────────────────

class _RouteVisual extends StatelessWidget {
  final String source;
  final String destination;

  const _RouteVisual({required this.source, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          children: [
            Container(
              width: 12, height: 12,
              decoration: const BoxDecoration(
                  color: Color(0xFF4CD97B), shape: BoxShape.circle),
            ),
            Container(
              width: 2, height: 28,
              color: AppColors.border,
            ),
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                  color: AppColors.secondary, shape: BoxShape.circle),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(source,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const SizedBox(height: 14),
              Text(destination,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Quick action panel (details screen version) ───────────────────────────────

class _QuickActionPanel extends StatelessWidget {
  final AdminBookingStatus status;
  final void Function(String) onStatusChange;

  const _QuickActionPanel({required this.status, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      AdminBookingStatus.pending => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BigActionBtn(
              label: 'Confirm Booking',
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.secondary,
              onTap: () => onStatusChange('confirmed'),
            ),
            const SizedBox(height: 10),
            _BigActionBtn(
              label: 'Cancel Booking',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFE05050),
              onTap: () => onStatusChange('cancelled'),
            ),
          ],
        ),
      AdminBookingStatus.confirmed => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BigActionBtn(
              label: 'Mark as On Route',
              icon: Icons.directions_car_rounded,
              color: const Color(0xFF4A90D9),
              onTap: () => onStatusChange('on_route'),
            ),
            const SizedBox(height: 10),
            _BigActionBtn(
              label: 'Cancel Booking',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFE05050),
              onTap: () => onStatusChange('cancelled'),
            ),
          ],
        ),
      AdminBookingStatus.onRoute => _BigActionBtn(
          label: 'Mark as Completed',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF55D17A),
          onTap: () => onStatusChange('completed'),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _BigActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _BigActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
