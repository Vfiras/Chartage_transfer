import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/admin_booking.dart';
import 'admin_card.dart';

class BookingCard extends StatelessWidget {
  final AdminBooking booking;
  final VoidCallback onViewDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  // Called with the next status string ('confirmed', 'on_route', etc.)
  final void Function(String newStatus)? onStatusChange;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onViewDetails,
    required this.onEdit,
    required this.onDelete,
    this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      label: booking.reference,
      value: booking.price,
      subtitle: booking.paymentMethod,
      icon: Icons.receipt_long_rounded,
      accentColor: AppColors.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowLabelValue('Pickup', booking.pickupDateTime.isNotEmpty
              ? booking.pickupDateTime
              : '—'),
          const SizedBox(height: 10),
          _RoutePill(source: booking.source, destination: booking.destination),
          const SizedBox(height: 12),
          _RowLabelValue('Client', booking.clientName),
          const SizedBox(height: 6),
          _RowLabelValue('Phone', booking.clientPhone.isNotEmpty ? booking.clientPhone : '—'),
          const SizedBox(height: 12),

          // Status badge
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: booking.status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                booking.status.label,
                style: TextStyle(
                  color: booking.status.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          // ── Quick status action buttons ─────────────────────────────────
          if (onStatusChange != null) ...[
            const SizedBox(height: 12),
            _QuickActions(status: booking.status, onStatusChange: onStatusChange!),
          ],

          const SizedBox(height: 14),

          // ── Management row ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Details',
                  icon: Icons.visibility_outlined,
                  onTap: onViewDetails,
                  fill: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  onTap: onEdit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  onTap: onDelete,
                  danger: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quick status actions ───────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final AdminBookingStatus status;
  final void Function(String) onStatusChange;

  const _QuickActions({required this.status, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      AdminBookingStatus.pending => Row(
          children: [
            Expanded(
              child: _StatusBtn(
                label: 'Approve',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.secondary,
                onTap: () => onStatusChange('confirmed'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusBtn(
                label: 'Reject',
                icon: Icons.cancel_outlined,
                color: const Color(0xFFE05050),
                onTap: () => onStatusChange('cancelled'),
              ),
            ),
          ],
        ),
      AdminBookingStatus.confirmed => Row(
          children: [
            Expanded(
              child: _StatusBtn(
                label: 'On Route',
                icon: Icons.directions_car_rounded,
                color: const Color(0xFF4A90D9),
                onTap: () => onStatusChange('on_route'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatusBtn(
                label: 'Cancel',
                icon: Icons.cancel_outlined,
                color: const Color(0xFFE05050),
                onTap: () => onStatusChange('cancelled'),
              ),
            ),
          ],
        ),
      AdminBookingStatus.onRoute => _StatusBtn(
          label: 'Complete',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF55D17A),
          onTap: () => onStatusChange('completed'),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatusBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
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

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _RowLabelValue extends StatelessWidget {
  final String label;
  final String value;

  const _RowLabelValue(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF7B7D7D),
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePill extends StatelessWidget {
  final String source;
  final String destination;

  const _RoutePill({required this.source, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CD97B),
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 18, color: AppColors.border),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(destination,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool fill;
  final bool danger;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.fill = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? AppColors.danger.withValues(alpha: 0.14)
        : fill
            ? AppColors.secondary
            : AppColors.surfaceElevated;
    final fg = danger
        ? const Color(0xFFD05050)
        : fill
            ? AppColors.primary
            : AppColors.textPrimary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: fill || danger ? Colors.transparent : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
