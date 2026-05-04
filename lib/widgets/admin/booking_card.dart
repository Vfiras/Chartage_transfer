import 'package:flutter/material.dart';

import '../../models/admin_booking.dart';
import '../../theme/app_colors.dart';
import 'admin_card.dart';

class BookingCard extends StatelessWidget {
  final AdminBooking booking;
  final VoidCallback onViewDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const BookingCard({
    super.key,
    required this.booking,
    required this.onViewDetails,
    required this.onEdit,
    required this.onDelete,
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
          _RowLabelValue('Pickup time', booking.pickupDateTime),
          const SizedBox(height: 10),
          _RoutePill(source: booking.source, destination: booking.destination),
          const SizedBox(height: 12),
          _RowLabelValue('Supplier', booking.supplierName),
          const SizedBox(height: 6),
          _RowLabelValue('Client', booking.clientName),
          const SizedBox(height: 6),
          _RowLabelValue('Payment', booking.paymentMethod),
          const SizedBox(height: 12),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'View details',
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
          width: 86,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF8A8A8A),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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

  const _RoutePill({
    required this.source,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CD97B),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 18,
                color: const Color(0x2CFFFFFF),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
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
                Text(
                  source,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  destination,
                  style: const TextStyle(
                    color: Color(0xFF9A9A9A),
                    fontSize: 13,
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
    final background = danger
        ? const Color(0xFF2D1717)
        : fill
            ? AppColors.secondary
            : const Color(0xFF131313);
    final foreground = danger
        ? const Color(0xFFFF7A7A)
        : fill
            ? AppColors.primary
            : Colors.white;

    return Material(
      color: background,
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
              color: fill || danger ? Colors.transparent : const Color(0x1FFFFFFF),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
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
