import 'package:flutter/material.dart';

import '../data/home_data.dart';
import '../models/booking_data.dart';
import '../models/vehicle.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/fallback_network_image.dart';
import '../widgets/common/primary_button.dart';
import 'booking_confirmation_screen.dart';

class BookingFleetScreen extends StatefulWidget {
  final BookingData data;

  const BookingFleetScreen({
    super.key,
    required this.data,
  });

  @override
  State<BookingFleetScreen> createState() => _BookingFleetScreenState();
}

class _BookingFleetScreenState extends State<BookingFleetScreen> {
  Vehicle? _selected;

  double _estimatePrice(Vehicle vehicle) {
    final base = vehicle.price.toDouble();
    return widget.data.tripType == 'round-trip' ? base * 1.85 : base;
  }

  void _confirm() {
    if (_selected == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingConfirmationScreen(
          data: widget.data,
          vehicle: _selected!,
          totalPrice: _estimatePrice(_selected!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Select Vehicle'),
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
                Text(
                  'Trip Summary',
                  style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                _summaryRow('Type', widget.data.tripType == 'one-way' ? 'One Way' : 'Round Trip'),
                _summaryRow('Pickup', widget.data.pickup),
                _summaryRow('Destination', widget.data.destination),
                _summaryRow('Date', widget.data.date),
                _summaryRow('Time', widget.data.time),
                _summaryRow('Passengers', '${widget.data.passengers}'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Choose your car',
            style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          ...HomeData.vehicles.map((vehicle) {
            final selected = _selected?.id == vehicle.id;
            final total = _estimatePrice(vehicle);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => setState(() => _selected = vehicle),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  radius: 22,
                  backgroundColor: selected ? AppColors.chipGoldBg : AppColors.surface,
                  borderColor: selected ? AppColors.secondary : AppColors.border,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
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
                              style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vehicle.model,
                              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${total.toStringAsFixed(0)} TND',
                              style: AppTextStyles.title.copyWith(color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle_rounded, color: AppColors.secondary),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          PrimaryButton(
            text: _selected == null ? 'Select a car to continue' : 'Continue to Confirmation',
            onPressed: _selected == null ? null : _confirm,
            trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
