import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';
import '../core/services/trip_service.dart';
import '../models/booking_data.dart';
import '../models/vehicle.dart';
import '../shared/widgets/common/luxury_components.dart';
import '../widgets/common/fallback_network_image.dart';
import 'booking_success_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
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
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  bool _loading = false;

  Future<void> _confirm() async {
    setState(() => _loading = true);
    final user = AuthService.instance.currentUser;
    final isGuest = AuthService.instance.isGuest;
    try {
      final trip = await const TripService().createBooking({
        'user_id': isGuest ? null : user?.id,
        'passenger_name':
            isGuest ? 'Guest Passenger' : user?.name ?? 'Passenger',
        'passenger_phone': widget.data.contactPhone,
        'pickup_location': widget.data.pickup,
        'destination_name': widget.data.destination,
        'destination_city': widget.data.destination,
        'vehicle_type': widget.vehicle.name,
        'estimated_earnings': widget.totalPrice,
        'pickup_time':
            '${widget.data.departureDate} ${widget.data.departureTime}',
        'trip_type': widget.data.tripType,
        'departure_date': widget.data.departureDate,
        'departure_time': widget.data.departureTime,
        'return_date':
            widget.data.returnDate.isEmpty ? null : widget.data.returnDate,
        'return_time':
            widget.data.returnTime.isEmpty ? null : widget.data.returnTime,
        'passenger_count': widget.data.passengers,
        'luggage_count': widget.data.luggageCount,
        'promo_code':
            widget.data.promoCode.isEmpty ? null : widget.data.promoCode,
        'dynamic_surcharge': widget.data.dynamicSurcharge,
        'discount_amount': widget.data.discountAmount,
        'guest_email': isGuest ? widget.data.contactEmail : null,
        'guest_phone': isGuest ? widget.data.contactPhone : null,
        'contact_email': widget.data.contactEmail,
        'contact_phone': widget.data.contactPhone,
        'vehicle_class': widget.vehicle.name,
        'total_price': widget.totalPrice,
        'is_guest': isGuest,
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            tripId: trip.id,
            data: widget.data,
            vehicle: widget.vehicle,
            totalPrice: widget.totalPrice,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return LuxuryScaffold(
      title: 'Confirm Booking',
      subtitle: 'Review your transfer',
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LuxuryCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 138,
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FallbackNetworkImage(
                          url: widget.vehicle.image,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          alignment: Alignment.bottomLeft,
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Color(0xDD0A0A0A),
                              ],
                            ),
                          ),
                          child: Text(
                            widget.vehicle.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookingInfoRow(label: 'Pickup', value: data.pickup),
                      BookingInfoRow(
                          label: 'Destination', value: data.destination),
                      BookingInfoRow(
                          label: 'Trip type',
                          value: data.isRoundTrip ? 'Round Trip' : 'One Way'),
                      BookingInfoRow(
                          label: 'Departure',
                          value: '${data.departureDate} ${data.departureTime}'),
                      if (data.isRoundTrip)
                        BookingInfoRow(
                            label: 'Return',
                            value: '${data.returnDate} ${data.returnTime}'),
                      BookingInfoRow(
                        label: 'Passengers',
                        value:
                            '${data.passengers} passengers, ${data.luggageCount} bags',
                      ),
                      BookingInfoRow(
                          label: 'Contact',
                          value: '${data.contactEmail}\n${data.contactPhone}'),
                      const Divider(color: AppColors.border, height: 26),
                      BookingInfoRow(
                        label: 'Subtotal',
                        value: '${data.subtotalPrice.toStringAsFixed(0)} TND',
                      ),
                      if (data.dynamicSurcharge > 0)
                        BookingInfoRow(
                          label: 'Adjustments',
                          value:
                              '+${data.dynamicSurcharge.toStringAsFixed(0)} TND',
                        ),
                      if (data.promoCode.isNotEmpty)
                        BookingInfoRow(
                          label: 'Promo',
                          value:
                              '${data.promoCode} -${data.discountAmount.toStringAsFixed(0)} TND',
                          valueColor: AppColors.green,
                        ),
                      BookingInfoRow(
                        label: 'Total',
                        value: '${widget.totalPrice.toStringAsFixed(0)} TND',
                        valueColor: AppColors.secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const LuxuryCard(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.secondary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Fixed price, professional driver, and no hidden fees.',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LuxuryButton(
            text: 'Confirm Booking',
            loading: _loading,
            onPressed: _confirm,
            icon: const Icon(Icons.check_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
