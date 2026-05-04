import 'package:flutter/material.dart';

import '../../models/admin_booking.dart';
import '../../theme/app_colors.dart';
import '../../widgets/admin/booking_card.dart';
import 'admin_booking_details_screen.dart';

class AdminBookingsScreen extends StatelessWidget {
  final ValueChanged<AdminBooking> onOpenBookingDetails;

  const AdminBookingsScreen({
    super.key,
    required this.onOpenBookingDetails,
  });

  @override
  Widget build(BuildContext context) {
    final bookings = AdminBooking.sampleData;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
        children: [
          const Text(
            'Bookings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scroll through bookings as mobile cards instead of desktop tables.',
            style: TextStyle(
              color: Color(0xFF9A9A9A),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          for (final booking in bookings) ...[
            BookingCard(
              booking: booking,
              onViewDetails: () => onOpenBookingDetails(booking),
              onEdit: () {},
              onDelete: () {},
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
