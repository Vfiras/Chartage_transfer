import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/routing/app_routes.dart';
import '../core/services/auth_service.dart';
import '../core/services/pricing_service.dart';
import '../core/services/vehicle_catalog_service.dart';
import '../models/booking_data.dart';
import '../models/vehicle.dart';
import '../shared/widgets/common/luxury_components.dart';
import 'contact_confirmation_screen.dart';

class BookingFleetScreen extends StatefulWidget {
  final BookingData data;

  const BookingFleetScreen({super.key, required this.data});

  @override
  State<BookingFleetScreen> createState() => _BookingFleetScreenState();
}

class _BookingFleetScreenState extends State<BookingFleetScreen> {
  Vehicle? _selected;
  late Future<_FleetPayload> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_FleetPayload> _load() async {
    final vehicles = await const VehicleCatalogService().listVehicles();
    final rules = await const PricingService().rules();
    return _FleetPayload(vehicles: vehicles, rules: rules);
  }

  PriceEstimate _priceFor(Vehicle vehicle, PricingRules rules) {
    return const PricingService().estimate(
      data: widget.data,
      vehicle: vehicle,
      rules: rules,
    );
  }

  Future<void> _continue(PricingRules rules) async {
    final selected = _selected;
    if (selected == null) return;

    if (AuthService.instance.isGuest) {
      _showLoginRequired();
      return;
    }

    setState(() => _busy = true);
    final preview = _priceFor(selected, rules);
    final discount = await const PricingService().promoDiscount(
      widget.data.promoCode,
      preview.basePrice + preview.dynamicSurcharge,
    );
    final finalEstimate = const PricingService().estimate(
      data: widget.data,
      vehicle: selected,
      rules: rules,
      promoDiscount: discount,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    widget.data
      ..vehicleId = selected.id
      ..vehicleClass = selected.name
      ..seats = selected.seatCount
      ..luggage = selected.bags
      ..subtotalPrice = finalEstimate.basePrice
      ..dynamicSurcharge = finalEstimate.dynamicSurcharge
      ..discountAmount = finalEstimate.discount
      ..totalPrice = finalEstimate.total;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ContactConfirmationScreen(data: widget.data, vehicle: selected),
      ),
    );
  }

  void _showLoginRequired() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LuxuryHeader(
              title: 'Login required',
              subtitle: 'Guests can browse vehicles and prices only.',
            ),
            const SizedBox(height: 16),
            const LuxuryCard(
              child: Text(
                'Create an account or login before reserving a ride.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.45),
              ),
            ),
            const SizedBox(height: 16),
            LuxuryButton(
              text: 'Login',
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (route) => false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Choose Your Vehicle',
      subtitle: 'Standard, VIP, Van, and Luxury',
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TripSummary(data: widget.data),
          const SizedBox(height: 18),
          FutureBuilder<_FleetPayload>(
            future: _future,
            builder: (context, snapshot) {
              final payload = snapshot.data;
              if (snapshot.connectionState == ConnectionState.waiting ||
                  payload == null) {
                return const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final vehicle in payload.vehicles)
                    VehicleSelectionCard(
                      image: vehicle.image,
                      name: vehicle.name,
                      subtitle: vehicle.available
                          ? '${_category(vehicle)} available'
                          : 'Currently unavailable',
                      seats: vehicle.seatCount,
                      bags: vehicle.bags,
                      price: _priceFor(vehicle, payload.rules).total,
                      selected: _selected?.id == vehicle.id,
                      onTap: vehicle.available
                          ? () => setState(() => _selected = vehicle)
                          : () {},
                    ),
                  const SizedBox(height: 4),
                  LuxuryCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Selected fare',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _selected == null
                              ? '--'
                              : '${_priceFor(_selected!, payload.rules).total.toStringAsFixed(0)} TND',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LuxuryButton(
                    text: AuthService.instance.isGuest
                        ? 'Login to Reserve'
                        : 'Continue',
                    loading: _busy,
                    onPressed: _selected == null
                        ? null
                        : () => _continue(payload.rules),
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _category(Vehicle vehicle) {
    if (vehicle.category.isNotEmpty) return vehicle.category;
    if (vehicle.label.isNotEmpty) return vehicle.label;
    return vehicle.name;
  }
}

class _FleetPayload {
  final List<Vehicle> vehicles;
  final PricingRules rules;

  const _FleetPayload({required this.vehicles, required this.rules});
}

class _TripSummary extends StatelessWidget {
  final BookingData data;

  const _TripSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trip summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                children: [
                  Icon(
                    Icons.radio_button_checked_rounded,
                    color: AppColors.secondary,
                    size: 18,
                  ),
                  SizedBox(height: 18),
                  Icon(
                    Icons.location_on_rounded,
                    color: AppColors.green,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.pickup.isEmpty ? 'Pickup location' : data.pickup,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      data.destination.isEmpty
                          ? 'Destination'
                          : data.destination,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Meta(
                icon: Icons.calendar_month_rounded,
                label: data.departureDate.isEmpty ? 'Date' : data.departureDate,
              ),
              const SizedBox(width: 10),
              _Meta(
                icon: Icons.schedule_rounded,
                label: data.departureTime.isEmpty ? 'Time' : data.departureTime,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Meta(
                icon: Icons.groups_rounded,
                label: '${data.passengers} pax',
              ),
              const SizedBox(width: 10),
              _Meta(
                icon: Icons.luggage_rounded,
                label: '${data.luggageCount} bags',
              ),
            ],
          ),
          if (data.promoCode.isNotEmpty) ...[
            const SizedBox(height: 10),
            LuxuryStatusChip(label: data.promoCode),
          ],
          if (data.isRoundTrip) ...[
            const SizedBox(height: 10),
            Text(
              'Return: ${data.returnDate} ${data.returnTime}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Meta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.secondary, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
