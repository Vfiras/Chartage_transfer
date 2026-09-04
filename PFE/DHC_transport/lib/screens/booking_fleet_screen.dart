import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/routing/app_routes.dart';
import '../core/services/auth_service.dart';
import '../core/services/language_service.dart';
import '../core/services/pricing_service.dart';
import '../core/services/vehicle_catalog_service.dart';
import '../models/booking_data.dart';
import '../models/vehicle.dart';
import '../shared/widgets/client/premium_client_components.dart';
import '../widgets/common/fallback_network_image.dart';
import '../widgets/common/luxury_skeleton.dart';
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
  late String _tripType; // 'one-way' | 'round-trip'
  // Cache one batch quote per trip type so toggling back is instant.
  final Map<String, RealEstimateResult?> _realCache = {};

  @override
  void initState() {
    super.initState();
    _tripType = widget.data.tripType;
    _future = _load();
  }

  Future<_FleetPayload> _load() async {
    final vehicles = await const VehicleCatalogService().listVehicles();
    final rules = await const PricingService().rules();
    final real = await _realFor(_tripType);
    return _FleetPayload(
      vehicles: _fitting(vehicles),
      totalCount: vehicles.length,
      rules: rules,
      real: real,
    );
  }

  /// Only vehicles that can actually carry the requested group. A car the
  /// party does not fit into is not an option, so it is hidden outright
  /// rather than shown disabled.
  ///
  /// A vehicle reporting 0 seats/bags has no capacity data rather than zero
  /// capacity, so it is kept — hiding it would empty the list on incomplete
  /// records.
  List<Vehicle> _fitting(List<Vehicle> all) {
    final passengers = widget.data.passengers;
    final luggage = widget.data.luggageCount;
    return all.where((v) {
      final seats = v.seatCount;
      final bags = v.bags;
      final seatsOk = seats <= 0 || seats >= passengers;
      final bagsOk = bags <= 0 || bags >= luggage;
      return seatsOk && bagsOk;
    }).toList(growable: false);
  }

  Future<RealEstimateResult?> _realFor(String tripType) async {
    if (_realCache.containsKey(tripType)) return _realCache[tripType];
    final result = await const PricingService()
        .realEstimates(data: widget.data, tripTypeOverride: tripType);
    _realCache[tripType] = result;
    return result;
  }

  void _setTripType(String value) {
    if (_tripType == value) return;
    setState(() {
      _tripType = value;
      widget.data.tripType = value;
      _future = _load(); // cached quotes resolve instantly
    });
  }

  PriceEstimate _priceFor(Vehicle vehicle, PricingRules rules) {
    return const PricingService().estimate(
      data: widget.data,
      vehicle: vehicle,
      rules: rules,
    );
  }

  /// Real distance-based price when the quote is available; local fallback else.
  double _cardPrice(Vehicle vehicle, _FleetPayload payload) {
    final real = payload.real?.byVehicleId[vehicle.backendId];
    if (real != null) return real.totalEur;
    return _priceFor(vehicle, payload.rules).total;
  }

  String _cardCurrency(Vehicle vehicle, _FleetPayload payload) {
    final real = payload.real?.byVehicleId[vehicle.backendId];
    // Fallback estimate is derived from the vehicle's EUR base_price, so the
    // honest label is EUR too — never TND.
    return real?.currency ?? 'EUR';
  }

  Future<void> _select(Vehicle vehicle, _FleetPayload payload) async {
    if (!vehicle.available || _busyVehicleId != null) return;
    if (AuthService.instance.isGuest) {
      _showLoginRequired();
      return;
    }

    setState(() => _busyVehicleId = vehicle.id);
    final rules = payload.rules;
    final real = payload.real?.byVehicleId[vehicle.backendId];
    PriceEstimate finalEstimate;
    if (real != null) {
      // Real engine total as base; configurable surcharges/promo layered on top.
      final discount = await const PricingService()
          .promoDiscount(widget.data.promoCode, real.totalEur);
      finalEstimate = const PricingService().estimateFromBase(
        base: real.totalEur,
        data: widget.data,
        rules: rules,
        promoDiscount: discount,
      );
      widget.data
        ..distanceKm = real.distanceKm
        ..durationHours = real.durationHours
        ..currency = real.currency;
    } else {
      final preview = _priceFor(vehicle, rules);
      final discount = await const PricingService().promoDiscount(
        widget.data.promoCode,
        preview.basePrice + preview.dynamicSurcharge,
      );
      finalEstimate = const PricingService().estimate(
        data: widget.data,
        vehicle: vehicle,
        rules: rules,
        promoDiscount: discount,
      );
      // Fallback estimate is EUR-denominated (from the vehicle's EUR
      // base_price) — pin the currency so every downstream screen agrees.
      widget.data.currency = 'EUR';
    }
    if (!mounted) return;
    setState(() => _busyVehicleId = null);

    widget.data
      ..vehicleId = vehicle.id
      ..backendVehicleId = vehicle.backendId
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
            final loading = snapshot.connectionState ==
                    ConnectionState.waiting ||
                snapshot.data == null;
            final payload = snapshot.data;
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
                const SizedBox(height: 18),
                _TripTypeToggle(value: _tripType, onChanged: _setTripType),
                if (payload?.real != null) ...[
                  const SizedBox(height: 12),
                  _RouteMetricsLine(real: payload!.real!),
                ],
                // Explains why some vehicles are missing from the list.
                if (!loading && payload!.totalCount > 0) ...[
                  const SizedBox(height: 18),
                  _CapacityNotice(
                    passengers: widget.data.passengers,
                    luggage: widget.data.luggageCount,
                    hidden: payload.totalCount - payload.vehicles.length,
                  ),
                ],
                const SizedBox(height: 28),
                // Loading = skeletons shaped like the product cards, so the
                // page keeps its structure while quotes come in.
                if (loading)
                  const SkeletonVehicleCards(count: 3)
                else if (payload!.vehicles.isEmpty && payload.totalCount > 0)
                  // The fleet loaded fine — nothing in it fits this party.
                  _NoFittingVehiclesState(
                    passengers: widget.data.passengers,
                    luggage: widget.data.luggageCount,
                    onBack: () => Navigator.of(context).maybePop(),
                  )
                else if (payload.vehicles.isEmpty)
                  _EmptyFleetState(onRetry: () {
                    setState(() => _future = _load());
                  })
                else
                  for (var i = 0; i < payload.vehicles.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: _VehicleChoiceCard(
                        vehicle: payload.vehicles[i],
                        price: _cardPrice(payload.vehicles[i], payload),
                        currency: _cardCurrency(payload.vehicles[i], payload),
                        isRealQuote: payload.real?.byVehicleId[
                                payload.vehicles[i].backendId] !=
                            null,
                        index: i,
                        busy: _busyVehicleId == payload.vehicles[i].id,
                        onSelect: () => _select(payload.vehicles[i], payload),
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
  /// Vehicles that fit the requested party.
  final List<Vehicle> vehicles;

  /// How many the catalogue returned before the capacity filter — used to
  /// tell "the fleet is empty" apart from "nothing fits this group".
  final int totalCount;
  final PricingRules rules;
  final RealEstimateResult? real;

  const _FleetPayload({
    required this.vehicles,
    required this.totalCount,
    required this.rules,
    this.real,
  });
}

class _TripTypeToggle extends StatelessWidget {
  final String value; // 'one-way' | 'round-trip'
  final ValueChanged<String> onChanged;

  const _TripTypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final textColor = PremiumClientTheme.text(context);
    Widget pill(String label, String type) {
      final selected = value == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? PremiumClientPalette.goldDeep
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF402D00)
                    : textColor.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PremiumClientTheme.surface(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PremiumClientTheme.glassBorder(context)),
      ),
      child: Row(
        children: [
          pill('One-way', 'one-way'),
          pill('Return', 'round-trip'),
        ],
      ),
    );
  }
}

class _RouteMetricsLine extends StatelessWidget {
  final RealEstimateResult real;

  const _RouteMetricsLine({required this.real});

  @override
  Widget build(BuildContext context) {
    final textColor = PremiumClientTheme.text(context);
    final mins = (real.durationHours * 60).round();
    final duration = mins >= 60
        ? '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2, '0')}m'
        : '${mins}m';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.route_rounded,
            color: textColor.withValues(alpha: 0.6), size: 15),
        const SizedBox(width: 6),
        Text(
          '${real.distanceKm.toStringAsFixed(1)} km  ·  ~$duration drive',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.66),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
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
  final String currency;
  final bool isRealQuote;
  final int index;
  final bool busy;
  final VoidCallback onSelect;

  const _VehicleChoiceCard({
    required this.vehicle,
    required this.price,
    this.currency = 'EUR',
    this.isRealQuote = false,
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
          // ── Header: kicker/name hero on the left, price close right ──
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
                    // The vehicle name is the hero of this card.
                    Text(
                      vehicle.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (vehicle.model.toLowerCase() !=
                        vehicle.name.toLowerCase()) ...[
                      const SizedBox(height: 3),
                      Text(
                        vehicle.model,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.60),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${price.toStringAsFixed(0)} $currency',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: PremiumClientPalette.gold,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // Honest microcopy: a real routed quote is all-inclusive;
                    // the offline fallback is an estimate.
                    isRealQuote ? 'ALL-INCLUSIVE' : 'ESTIMATED',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.50),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          // ── Vehicle plate ────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 180,
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: FallbackNetworkImage(
                url: vehicle.image,
                fit: BoxFit.contain,
                height: 168,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: 18),
          // ── Real features + select ───────────────────────────────────
          Row(
            children: [
              _SpecLine(
                  icon: Icons.groups_rounded,
                  label: '${vehicle.seatCount} Pax'),
              const SizedBox(width: 14),
              _SpecLine(
                  icon: Icons.luggage_outlined, label: '${vehicle.bags} Bags'),
              const SizedBox(width: 14),
              // Every Carthage transfer includes 1h of free waiting time —
              // a real selling point (replaces the old fake WiFi chip).
              const _SpecLine(icon: Icons.schedule_rounded, label: '1h Wait'),
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
                              fontWeight: FontWeight.w700,
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

/// Real empty state — shown when the fleet API returns nothing at all.
/// Tells the user which capacity the list is filtered to, so a missing
/// vehicle reads as "too small for your group" rather than "broken app".
class _CapacityNotice extends StatelessWidget {
  final int passengers;
  final int luggage;
  final int hidden;

  const _CapacityNotice({
    required this.passengers,
    required this.luggage,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final textColor = PremiumClientTheme.text(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: PremiumClientPalette.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: PremiumClientPalette.gold.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined,
              color: PremiumClientPalette.gold, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hidden > 0
                  ? l.t('fleet_filter_notice_hidden', args: {
                      'passengers': '$passengers',
                      'luggage': '$luggage',
                      'hidden': '$hidden',
                    })
                  : l.t('fleet_filter_notice', args: {
                      'passengers': '$passengers',
                      'luggage': '$luggage',
                    }),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.80),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The catalogue loaded, but nothing in it can carry this party.
class _NoFittingVehiclesState extends StatelessWidget {
  final int passengers;
  final int luggage;
  final VoidCallback onBack;

  const _NoFittingVehiclesState({
    required this.passengers,
    required this.luggage,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final textColor = PremiumClientTheme.text(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.no_transfer_outlined,
              color: textColor.withValues(alpha: 0.30), size: 44),
          const SizedBox(height: 14),
          Text(
            l.t('fleet_no_fit_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.t('fleet_no_fit_body', args: {
              'passengers': '$passengers',
              'luggage': '$luggage',
            }),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.60),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: onBack,
            child: Text(
              l.t('fleet_no_fit_action'),
              style: const TextStyle(
                color: PremiumClientPalette.gold,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFleetState extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyFleetState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final textColor = PremiumClientTheme.text(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.directions_car_outlined,
              color: textColor.withValues(alpha: 0.30), size: 44),
          const SizedBox(height: 14),
          Text(
            'Our fleet is unavailable right now',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Please check your connection and try again.',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.60),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Try again',
              style: TextStyle(
                color: PremiumClientPalette.gold,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
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
