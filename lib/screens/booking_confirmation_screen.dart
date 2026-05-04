import 'package:flutter/material.dart';

import '../models/booking_data.dart';
import '../models/vehicle.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/fallback_network_image.dart';
import '../widgets/common/primary_button.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final BookingData data;
  final Vehicle vehicle;
  final double totalPrice;

  const BookingConfirmationScreen({
    super.key,
    required this.data,
    required this.vehicle,
    required this.totalPrice,
  });

  @override
  Widget build(BuildContext context) {
    final ref = 'CT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Booking Confirmation'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            radius: 24,
            backgroundColor: AppColors.surface,
            borderColor: AppColors.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: FallbackNetworkImage(
                        url: vehicle.image,
                        width: 96,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.name,
                            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle.model,
                            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _row('Reference', ref),
                _row('Trip Type', data.tripType == 'one-way' ? 'One Way' : 'Round Trip'),
                _row('Pickup', data.pickup),
                _row('Destination', data.destination),
                _row('Date', data.date),
                _row('Time', data.time),
                _row('Passengers', '${data.passengers}'),
                _row('Vehicle', vehicle.name),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                _row(
                  'Total',
                  '${totalPrice.toStringAsFixed(0)} TND',
                  valueColor: AppColors.secondary,
                  labelColor: AppColors.textPrimary,
                  boldValue: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.all(16),
            radius: 24,
            backgroundColor: AppColors.chipGoldBg,
            borderColor: const Color(0x2EE6A200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your booking is ready',
                  style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'A driver will be assigned after you confirm. The fare shown above is the final estimate.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            text: 'Confirm Booking',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Booking confirmed: $ref')),
              );
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            trailing: const Icon(Icons.check_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    Color? labelColor,
    Color? valueColor,
    bool boldValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: labelColor ?? AppColors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: boldValue ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
