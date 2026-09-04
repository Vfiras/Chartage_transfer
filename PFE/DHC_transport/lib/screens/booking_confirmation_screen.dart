import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';
import '../core/services/language_service.dart';
import '../core/services/reward_service.dart';
import '../core/services/trip_service.dart';
import '../models/booking_data.dart';
import '../models/vehicle.dart';
import '../shared/widgets/common/route_map_view.dart';
import '../widgets/common/fallback_network_image.dart';
import '../widgets/common/luxury_cta.dart';
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

  /// Referral wallet balance. The server decides how much is actually spent —
  /// this is shown so the total on screen matches what will be charged.
  double _credits = 0;

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    if (AuthService.instance.isGuest) return;
    try {
      final res = await RewardService().getRewardsMe();
      if (!mounted) return;
      setState(() =>
          _credits = (res['referral_credits'] as num?)?.toDouble() ?? 0);
    } catch (_) {
      // A rewards hiccup must not block checkout; the server still applies
      // whatever balance exists when the booking is created.
    }
  }

  /// What the wallet will cover on this trip.
  double get _creditsApplied =>
      _credits <= 0 ? 0 : (_credits < widget.totalPrice ? _credits : widget.totalPrice);

  double get _payable => widget.totalPrice - _creditsApplied;

  Future<void> _confirm() async {
    setState(() => _loading = true);
    final user = AuthService.instance.currentUser;
    final isGuest = AuthService.instance.isGuest;
    try {
      final result = await const TripService().createBookingDetailed({
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
        'payment_method': widget.data.paymentMethod,
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            tripId: result.trip.id,
            data: widget.data,
            vehicle: widget.vehicle,
            // The server is the authority on the final amount.
            totalPrice: widget.totalPrice - result.creditsApplied,
            creditsApplied: result.creditsApplied,
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
    final user = AuthService.instance.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          color: AppColors.secondary, size: 20),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'CARTHAGE TRANSFER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: Color(0xFFC8A96B),
                      ),
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border:
                          Border.all(color: AppColors.secondary, width: 1.5),
                    ),
                    child: ClipOval(
                      child: (user?.avatarUrl != null &&
                              user!.avatarUrl!.isNotEmpty)
                          ? Image.network(
                              user.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.surface,
                                alignment: Alignment.center,
                                child: Icon(Icons.person_rounded,
                                    color: AppColors.secondary, size: 22),
                              ),
                            )
                          : Container(
                              color: AppColors.surface,
                              alignment: Alignment.center,
                              child: Icon(Icons.person_rounded,
                                  color: AppColors.secondary, size: 22),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero car image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 200,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FallbackNetworkImage(
                              url: widget.vehicle.image,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    const Color(0xEE020202),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 16,
                              left: 18,
                              right: 18,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'REVIEW YOUR TRANSFER',
                                    style: TextStyle(
                                      color: Color(0xFFC8A96B),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.vehicle.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),
                    // Prefer the exact coordinates resolved during search
                    // (Places autocomplete); fall back to the curated
                    // name-lookup for older flows without coords.
                    data.hasCoordinates
                        ? RouteMapView(
                            pickup:
                                LatLng(data.pickupLat!, data.pickupLng!),
                            destination: LatLng(data.destinationLat!,
                                data.destinationLng!),
                            pickupLabel: data.pickup,
                            destinationLabel: data.destination,
                            height: 200,
                            borderRadius: 20,
                          )
                        : RouteMapView.fromStrings(
                            pickup: data.pickup,
                            destination: data.destination,
                            height: 200,
                            borderRadius: 20,
                          ),
                    const SizedBox(height: 8),
                    // Quiet heading — the route map and receipt card are the
                    // heroes of this screen, not the label.
                    const Text(
                      'Confirm Booking',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Booking details card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          // VIP class header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: AppColors.goldBorder),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded,
                                          color: AppColors.secondary, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.vehicle.category.isNotEmpty
                                            ? widget.vehicle.category
                                                .toUpperCase()
                                            : 'EXECUTIVE CLASS',
                                        style: TextStyle(
                                          color: AppColors.secondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1),

                          // Info rows
                          _InfoRow(label: 'PICKUP', value: data.pickup),
                          _InfoRow(
                              label: 'DESTINATION', value: data.destination),
                          _InfoRow(
                            label: 'TRIP TYPE',
                            value: data.isRoundTrip ? 'Round Trip' : 'One Way',
                          ),
                          _InfoRow(
                            label: 'DEPARTURE',
                            value:
                                '${data.departureDate}  •  ${data.departureTime}',
                          ),
                          if (data.isRoundTrip)
                            _InfoRow(
                              label: 'RETURN',
                              value:
                                  '${data.returnDate}  •  ${data.returnTime}',
                            ),
                          _InfoRow(
                            label: 'PASSENGERS',
                            value:
                                '${data.passengers} passengers · ${data.luggageCount} bags',
                          ),
                          _InfoRow(
                            label: 'CONTACT',
                            value: '${data.contactEmail}\n${data.contactPhone}',
                          ),

                          // Price breakdown
                          Container(
                            margin: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                            height: 1,
                            color: AppColors.border,
                          ),
                          const SizedBox(height: 14),
                          _PriceRow(
                            label: 'Subtotal',
                            value:
                                '${data.subtotalPrice.toStringAsFixed(0)} ${data.currency}',
                          ),
                          if (data.dynamicSurcharge > 0)
                            _PriceRow(
                              label: 'Adjustments',
                              value:
                                  '+${data.dynamicSurcharge.toStringAsFixed(0)} ${data.currency}',
                              valueColor: AppColors.secondary,
                            ),
                          if (data.promoCode.isNotEmpty)
                            _PriceRow(
                              label: 'Promo (${data.promoCode})',
                              value:
                                  '-${data.discountAmount.toStringAsFixed(0)} ${data.currency}',
                              valueColor: AppColors.green,
                            ),
                          // Referral wallet — applied automatically, no code.
                          if (_creditsApplied > 0)
                            _PriceRow(
                              label: LanguageService.instance
                                  .t('rewards_balance_row'),
                              value:
                                  '-${_creditsApplied.toStringAsFixed(2)} ${data.currency}',
                              valueColor: AppColors.green,
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'TOTAL',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  '${_payable.toStringAsFixed(2)} ${data.currency}',
                                  style: TextStyle(
                                    color: AppColors.secondary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_creditsApplied > 0)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 0, 18, 16),
                              child: Text(
                                LanguageService.instance
                                    .t('rewards_balance_note'),
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Shield banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.verified_user_outlined,
                                color: AppColors.secondary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Fixed price, professional driver, and no hidden fees.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Confirm button — the one CTA spec (52px / r14 / w800)
                    LuxuryCta(
                      text: 'Confirm Booking',
                      icon: Icons.check_rounded,
                      loading: _loading,
                      onTap: _loading ? null : _confirm,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
