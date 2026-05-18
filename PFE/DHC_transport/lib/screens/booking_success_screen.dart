import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/routing/app_routes.dart';
import '../models/booking_data.dart';
import '../models/vehicle.dart';
import '../shared/widgets/common/luxury_components.dart';

class BookingSuccessScreen extends StatelessWidget {
  final String tripId;
  final BookingData data;
  final Vehicle vehicle;
  final double totalPrice;

  const BookingSuccessScreen({
    super.key,
    required this.tripId,
    required this.data,
    required this.vehicle,
    required this.totalPrice,
  });

  void _goHome(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.clientShell, (route) => false,
        arguments: 0);
  }

  void _viewRides(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.clientShell, (route) => false,
        arguments: 1);
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      scrollable: false,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 96,
                height: 96,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.14),
                  border: Border.all(color: AppColors.secondary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.24),
                      blurRadius: 34,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.secondary, size: 62),
              ),
              const Text(
                'Booking Confirmed',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your transfer request has been sent to operations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              LuxuryCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BookingInfoRow(
                        label: 'Booking ID',
                        value: tripId,
                        valueColor: AppColors.secondary),
                    BookingInfoRow(label: 'Status', value: 'Requested'),
                    BookingInfoRow(
                        label: 'Route',
                        value: '${data.pickup}\n${data.destination}'),
                    BookingInfoRow(
                        label: 'Pickup time',
                        value: '${data.departureDate} ${data.departureTime}'),
                    BookingInfoRow(label: 'Vehicle', value: vehicle.name),
                    BookingInfoRow(
                      label: 'Passengers',
                      value:
                          '${data.passengers} passengers, ${data.luggageCount} bags',
                    ),
                    BookingInfoRow(
                        label: 'Total',
                        value: '${totalPrice.toStringAsFixed(0)} TND',
                        valueColor: AppColors.secondary),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LuxuryButton(
                text: 'View My Rides',
                onPressed: () => _viewRides(context),
                icon: const Icon(Icons.directions_car_rounded,
                    color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              LuxuryButton(
                text: 'Return Home',
                onPressed: () => _goHome(context),
                variant: LuxuryButtonVariant.outline,
                icon: const Icon(Icons.home_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
