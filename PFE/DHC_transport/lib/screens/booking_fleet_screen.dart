import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/routing/app_routes.dart';
import '../core/services/auth_service.dart';
import '../core/services/pricing_service.dart';
import '../core/services/vehicle_catalog_service.dart';
import '../models/booking_data.dart';
import '../models/vehicle.dart';
import '../shared/widgets/client/premium_client_components.dart';
import '../widgets/common/fallback_network_image.dart';
import 'contact_confirmation_screen.dart';

class BookingFleetScreen extends StatefulWidget {
  final BookingData data;

  const BookingFleetScreen({super.key, required this.data});

  @override
  State<BookingFleetScreen> createState() => _BookingFleetScreenState();
}

class _BookingFleetScreenState extends State<BookingFleetScreen> {
  late Future<_FleetPayload> _future;
  int? _busyVehicleId;

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

  Future<void> _select(Vehicle vehicle, PricingRules rules) async {
    if (!vehicle.available || _busyVehicleId != null) return;
    if (AuthService.instance.isGuest) {
      _showLoginRequired();
      return;
    }

    setState(() => _busyVehicleId = vehicle.id);
    final preview = _priceFor(vehicle, rules);
    final discount = await const PricingService().promoDiscount(
      widget.data.promoCode,
      preview.basePrice + preview.dynamicSurcharge,
    );
    final finalEstimate = const PricingService().estimate(
      data: widget.data,
      vehicle: vehicle,
      rules: rules,
      promoDiscount: discount,
    );
    if (!mounted) return;
    setState(() => _busyVehicleId = null);

    widget.data
      ..vehicleId = vehicle.id
      ..vehicleClass = vehicle.name
      ..seats = vehicle.seatCount
      ..luggage = vehicle.bags
      ..subtotalPrice = finalEstimate.basePrice
      ..dynamicSurcharge = finalEstimate.dynamicSurcharge
      ..discountAmount = finalEstimate.discount
      ..totalPrice = finalEstimate.total;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ContactConfirmationScreen(data: widget.data, vehicle: vehicle),
      ),
    );
  }

  void _showLoginRequired() {
    final textColor = PremiumClientTheme.text(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PremiumClientTheme.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Login Required',
              style: TextStyle(
                color: textColor,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Guests can browse the fleet. Login before reserving a chauffeur.',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            PremiumPrimaryButton(
              text: 'Login',
              onTap: () => Navigator.of(context).pushNamedAndRemoveUntil(
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
    return Scaffold(
      backgroundColor: PremiumClientTheme.background(context),
      body: SafeArea(
        child: FutureBuilder<_FleetPayload>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.data == null) {
              return const Center(
                child: CircularProgressIndicator(
                  color: PremiumClientPalette.gold,
                ),
              );
            }
            final payload = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _FleetTopBar(onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 26),
                Text(
                  'Select Your Ride',
                  style: TextStyle(
                    color: PremiumClientTheme.text(context),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 22),
                _TripSummaryCard(data: widget.data),
                const SizedBox(height: 40),
                for (var i = 0; i < payload.vehicles.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: _VehicleChoiceCard(
                      vehicle: payload.vehicles[i],
                      price:
                          _priceFor(payload.vehicles[i], payload.rules).total,
                      index: i,
                      busy: _busyVehicleId == payload.vehicles[i].id,
                      onSelect: () =>
                          _select(payload.vehicles[i], payload.rules),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FleetPayload {
  final List<Vehicle> vehicles;
  final PricingRules rules;

  const _FleetPayload({required this.vehicles, required this.rules});
}

class _FleetTopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _FleetTopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final firstName = AuthService.instance.isGuest
        ? 'Guest'
        : user?.name.split(' ').first ?? 'Alex';
    return Row(
      children: [
        const PremiumAvatar(size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Welcome, $firstName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PremiumClientPalette.gold,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        GestureDetector(
          onTap: onBack,
          child: const Icon(
            Icons.menu_rounded,
            color: PremiumClientPalette.gold,
            size: 28,
          ),
        ),
      ],
    );
  }
}

class _TripSummaryCard extends StatelessWidget {
  final BookingData data;

  const _TripSummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = PremiumClientTheme.isDark(context);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.08);
    final tickColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.16);
    return PremiumGlassPanel(
      borderRadius: BorderRadius.circular(10),
      color: PremiumClientTheme.elevated(context).withValues(alpha: 0.72),
      borderColor: PremiumClientTheme.glassBorder(context),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  _RouteDot(filled: false),
                  Container(
                    width: 1,
                    height: 26,
                    color: tickColor,
                  ),
                  const _RouteDot(filled: true),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryText(label: 'PICKUP', value: data.pickup),
                    const SizedBox(height: 12),
                    _SummaryText(label: 'DESTINATION', value: data.destination),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: dividerColor),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMeta(
                  icon: Icons.calendar_today_outlined,
                  label: 'DATE',
                  value: _formatDate(data.departureDate),
                ),
              ),
              Expanded(
                child: _SummaryMeta(
                  icon: Icons.schedule_rounded,
                  label: 'TIME',
                  value: data.departureTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMeta(
                  icon: Icons.person_outline_rounded,
                  label: 'PAX',
                  value: '${data.passengers} Passengers',
                ),
              ),
              Expanded(
                child: _SummaryMeta(
                  icon: Icons.luggage_outlined,
                  label: 'BAGS',
                  value: '${data.luggageCount} Luggage',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(value));
    } catch (_) {
      return value;
    }
  }
}

class _RouteDot extends StatelessWidget {
  final bool filled;

  const _RouteDot({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? PremiumClientPalette.goldDeep : Colors.transparent,
        border: Border.all(color: PremiumClientPalette.goldDeep, width: 1.5),
      ),
    );
  }
}

class _SummaryText extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textColor = PremiumClientTheme.text(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.52),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SummaryMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = PremiumClientTheme.text(context);
    return Row(
      children: [
        Icon(icon, color: PremiumClientPalette.gold, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.52),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VehicleChoiceCard extends StatelessWidget {
  final Vehicle vehicle;
  final double price;
  final int index;
  final bool busy;
  final VoidCallback onSelect;

  const _VehicleChoiceCard({
    required this.vehicle,
    required this.price,
    required this.index,
    required this.busy,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = PremiumClientTheme.isDark(context);
    final textColor = PremiumClientTheme.text(context);
    final badge = _badge(index, vehicle);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: PremiumClientTheme.surface(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badge.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge.label,
                        style: TextStyle(
                          color: badge.color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      vehicle.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle.model,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.72),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${price.toStringAsFixed(0)} TND',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: PremiumClientPalette.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'FIXED RATE',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.58),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 190,
            child: Center(
              child: Container(
                height: 180,
                width: double.infinity,
                color: Colors.white,
                child: FallbackNetworkImage(
                  url: vehicle.image,
                  fit: BoxFit.contain,
                  height: 180,
                  width: double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SpecLine(
                  icon: Icons.groups_rounded,
                  label: '${vehicle.seatCount} Pax'),
              const SizedBox(width: 14),
              _SpecLine(
                  icon: Icons.luggage_outlined, label: '${vehicle.bags} Bags'),
              if (index == 0) ...[
                const SizedBox(width: 14),
                const _SpecLine(icon: Icons.wifi_rounded, label: 'Free WiFi'),
              ],
              const Spacer(),
              GestureDetector(
                onTap: onSelect,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 92),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: PremiumClientPalette.goldDeep,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Color(0xFF402D00),
                            ),
                          )
                        : const Text(
                            'Select',
                            style: TextStyle(
                              color: Color(0xFF402D00),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _VehicleBadge _badge(int index, Vehicle vehicle) {
    if (index == 0) {
      return const _VehicleBadge('MOST POPULAR', PremiumClientPalette.goldDeep);
    }
    if (vehicle.model.toLowerCase().contains('electric') ||
        vehicle.name.toLowerCase().contains('tesla')) {
      return const _VehicleBadge('ZERO EMISSION', Color(0xFF4A90D9));
    }
    if (vehicle.seatCount >= 6) {
      return const _VehicleBadge('GROUP TRAVEL', Color(0xFFE9E1DA));
    }
    return const _VehicleBadge('EXECUTIVE', PremiumClientPalette.goldDeep);
  }
}

class _VehicleBadge {
  final String label;
  final Color color;

  const _VehicleBadge(this.label, this.color);
}

class _SpecLine extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SpecLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final textColor = PremiumClientTheme.text(context);
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: textColor.withValues(alpha: 0.76),
            size: 15,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
