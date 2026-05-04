import 'package:flutter/material.dart';

import '../../models/admin_booking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin/admin_card.dart';

class AdminBookingDetailsScreen extends StatelessWidget {
  final AdminBooking booking;

  const AdminBookingDetailsScreen({
    super.key,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: Colors.white,
        title: const Text('Booking Details'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            AdminCard(
              label: booking.reference,
              value: booking.route,
              subtitle: booking.clientName,
              icon: Icons.receipt_long_rounded,
              accentColor: AppColors.secondary,
              child: Column(
                children: [
                  _DetailRow('Pickup', booking.pickupDateTime),
                  _DetailRow('Route', '${booking.source} → ${booking.destination}'),
                  _DetailRow('Supplier', booking.supplierName),
                  _DetailRow('Price', booking.price),
                  _DetailRow('Payment', booking.paymentMethod),
                  _DetailRow('Client', booking.clientName),
                  _DetailRow('Phone', booking.clientPhone),
                  _DetailRow('Status', booking.status.label),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AdminCard(
              label: 'Notes',
              value: 'Internal booking notes',
              subtitle: 'Use this area for operations remarks',
              icon: Icons.notes_rounded,
              child: Text(
                booking.notes,
                style: const TextStyle(
                  color: Color(0xFFD8D8D8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
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
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
