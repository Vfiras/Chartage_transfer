import 'package:intl/intl.dart';

import '../../data/home_data.dart';
import '../../models/booking_data.dart';
import '../../models/vehicle.dart';
import 'transport_api_client.dart';

class PricingRules {
  final int minimumBookingHours;
  final int modificationLimitHours;
  final int cancellationLimitHours;
  final bool nightEnabled;
  final int nightStartHour;
  final int nightEndHour;
  final double nightPercentage;
  final bool lastMinuteEnabled;
  final int lastMinuteWithinHours;
  final double lastMinutePercentage;
  final bool weekendEnabled;
  final double weekendPercentage;
  final bool seasonalEnabled;
  final double seasonalPercentage;

  const PricingRules({
    this.minimumBookingHours = 3,
    this.modificationLimitHours = 24,
    this.cancellationLimitHours = 24,
    this.nightEnabled = true,
    this.nightStartHour = 22,
    this.nightEndHour = 6,
    this.nightPercentage = 30,
    this.lastMinuteEnabled = true,
    this.lastMinuteWithinHours = 24,
    this.lastMinutePercentage = 20,
    this.weekendEnabled = true,
    this.weekendPercentage = 10,
    this.seasonalEnabled = false,
    this.seasonalPercentage = 0,
  });

  factory PricingRules.fromJson(Map<String, dynamic> json) {
    final night =
        (json['night_pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    final lastMinute =
        (json['last_minute_pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    final weekend =
        (json['weekend_pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    final seasonal =
        (json['seasonal_pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    return PricingRules(
      minimumBookingHours:
          (json['minimum_booking_hours'] as num?)?.toInt() ?? 3,
      modificationLimitHours:
          (json['modification_limit_hours'] as num?)?.toInt() ?? 24,
      cancellationLimitHours:
          (json['cancellation_limit_hours'] as num?)?.toInt() ?? 24,
      nightEnabled: night['enabled'] as bool? ?? true,
      nightStartHour: _hour(night['start_time']?.toString(), 22),
      nightEndHour: _hour(night['end_time']?.toString(), 6),
      nightPercentage: (night['percentage'] as num?)?.toDouble() ?? 30,
      lastMinuteEnabled: lastMinute['enabled'] as bool? ?? true,
      lastMinuteWithinHours:
          (lastMinute['within_hours'] as num?)?.toInt() ?? 24,
      lastMinutePercentage:
          (lastMinute['percentage'] as num?)?.toDouble() ?? 20,
      weekendEnabled: weekend['enabled'] as bool? ?? true,
      weekendPercentage: (weekend['percentage'] as num?)?.toDouble() ?? 10,
      seasonalEnabled: seasonal['enabled'] as bool? ?? false,
      seasonalPercentage: (seasonal['percentage'] as num?)?.toDouble() ?? 0,
    );
  }

  static int _hour(String? value, int fallback) {
    if (value == null || value.length < 2) return fallback;
    return int.tryParse(value.substring(0, 2)) ?? fallback;
  }
}

class PriceEstimate {
  final double basePrice;
  final double dynamicSurcharge;
  final double discount;
  final double total;
  final List<String> appliedRules;

  const PriceEstimate({
    required this.basePrice,
    required this.dynamicSurcharge,
    required this.discount,
    required this.total,
    required this.appliedRules,
  });
}

/// Real per-vehicle quote from POST /bookings/price-estimate — computed
/// server-side from the vehicle's pricing parameters and the Google
/// Directions distance for the actual route.
class RealVehicleEstimate {
  final String vehicleId; // backend Mongo id, e.g. "car-comfort-sedan"
  final String vehicleName;
  final double totalEur;
  final double distanceKm;
  final double durationHours;
  final String currency;
  final double initialFee;
  final double distanceCost;

  const RealVehicleEstimate({
    required this.vehicleId,
    required this.vehicleName,
    required this.totalEur,
    required this.distanceKm,
    required this.durationHours,
    required this.currency,
    required this.initialFee,
    required this.distanceCost,
  });

  factory RealVehicleEstimate.fromJson(
      Map<String, dynamic> json, double distanceKm, double durationHours) {
    final breakdown =
        (json['breakdown'] as Map?)?.cast<String, dynamic>() ?? {};
    return RealVehicleEstimate(
      vehicleId: json['vehicle_id']?.toString() ?? '',
      vehicleName: json['vehicle_name']?.toString() ?? '',
      totalEur: (json['total_eur'] as num?)?.toDouble() ?? 0,
      distanceKm: distanceKm,
      durationHours: durationHours,
      currency: json['currency']?.toString() ?? 'EUR',
      initialFee: (breakdown['initial_fee'] as num?)?.toDouble() ?? 0,
      distanceCost: (breakdown['distance_cost'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Result of one batch price-estimate call: route metrics + per-vehicle quotes.
class RealEstimateResult {
  final double distanceKm;
  final double durationHours;
  final Map<String, RealVehicleEstimate> byVehicleId;

  const RealEstimateResult({
    required this.distanceKm,
    required this.durationHours,
    required this.byVehicleId,
  });
}

class PricingService {
  const PricingService();

  /// Batch real quote for every available vehicle on the given route.
  /// One Directions call server-side; returns null when the request fails so
  /// callers can fall back to the local rules-based estimate.
  Future<RealEstimateResult?> realEstimates({
    required BookingData data,
    String? tripTypeOverride,
  }) async {
    if (!data.hasCoordinates) return null;
    try {
      final response = await TransportApiClient.instance.post(
        '/bookings/price-estimate',
        {
          'pickup_lat': data.pickupLat,
          'pickup_lng': data.pickupLng,
          'destination_lat': data.destinationLat,
          'destination_lng': data.destinationLng,
          'trip_type': (tripTypeOverride ?? data.tripType) == 'round-trip'
              ? 'return'
              : 'one_way',
        },
      );
      final distanceKm = (response['distance_km'] as num?)?.toDouble() ?? 0;
      final durationHours =
          (response['duration_hours'] as num?)?.toDouble() ?? 0;
      final estimates = <String, RealVehicleEstimate>{};
      for (final raw in (response['estimates'] as List? ?? const [])) {
        final est = RealVehicleEstimate.fromJson(
          (raw as Map).cast<String, dynamic>(),
          distanceKm,
          durationHours,
        );
        if (est.vehicleId.isNotEmpty) estimates[est.vehicleId] = est;
      }
      if (estimates.isEmpty) return null;
      return RealEstimateResult(
        distanceKm: distanceKm,
        durationHours: durationHours,
        byVehicleId: estimates,
      );
    } catch (_) {
      return null;
    }
  }

  /// Apply the configurable surcharge rules (night/weekend/last-minute/seasonal)
  /// and promo discount on top of a REAL distance-based base price.
  PriceEstimate estimateFromBase({
    required double base,
    required BookingData data,
    required PricingRules rules,
    double promoDiscount = 0,
  }) {
    final applied = <String>[];
    if (data.isRoundTrip) applied.add('Round trip');
    final departure = departureDateTime(data);
    var surcharge = 0.0;
    if (departure != null) {
      if (_isNight(departure.hour, rules)) {
        surcharge += base * (rules.nightPercentage / 100);
        applied
            .add('Night pricing +${rules.nightPercentage.toStringAsFixed(0)}%');
      }
      if (rules.weekendEnabled &&
          (departure.weekday == DateTime.saturday ||
              departure.weekday == DateTime.sunday)) {
        surcharge += base * (rules.weekendPercentage / 100);
        applied.add('Weekend +${rules.weekendPercentage.toStringAsFixed(0)}%');
      }
      if (rules.lastMinuteEnabled &&
          departure.difference(DateTime.now()).inHours <
              rules.lastMinuteWithinHours) {
        surcharge += base * (rules.lastMinutePercentage / 100);
        applied.add(
            'Last minute +${rules.lastMinutePercentage.toStringAsFixed(0)}%');
      }
      if (rules.seasonalEnabled) {
        surcharge += base * (rules.seasonalPercentage / 100);
        applied
            .add('Seasonal +${rules.seasonalPercentage.toStringAsFixed(0)}%');
      }
    }
    final subtotal = base + surcharge;
    final discount = promoDiscount.clamp(0, subtotal).toDouble();
    return PriceEstimate(
      basePrice: base,
      dynamicSurcharge: surcharge,
      discount: discount,
      total: subtotal - discount,
      appliedRules: applied,
    );
  }

  Future<PricingRules> rules() async {
    try {
      final response = await TransportApiClient.instance.get('/pricing/config');
      final payload =
          (response['pricing_config'] as Map?)?.cast<String, dynamic>() ?? {};
      return PricingRules.fromJson(payload);
    } catch (_) {
      return const PricingRules();
    }
  }

  Future<double> promoDiscount(String code, double subtotal) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty || subtotal <= 0) return 0;
    try {
      final response = await TransportApiClient.instance.post(
        '/pricing/promo/validate',
        {'code': normalized, 'subtotal': subtotal},
      );
      return (response['discount'] as num?)?.toDouble() ?? 0;
    } catch (_) {
      if (normalized == 'WELCOME10' || normalized == 'CDHC10') {
        return subtotal * 0.10;
      }
      if (normalized == 'CDHC5') return subtotal * 0.05;
      return 0;
    }
  }

  PriceEstimate estimate({
    required BookingData data,
    required Vehicle vehicle,
    required PricingRules rules,
    double promoDiscount = 0,
  }) {
    final applied = <String>[];
    final seatFactor =
        data.passengers > vehicle.seatCount && vehicle.seatCount > 0 ? 1.2 : 1;
    var base = vehicle.price.toDouble() * seatFactor;
    if (data.isRoundTrip) {
      base *= 1.85;
      applied.add('Round trip');
    }

    final departure = departureDateTime(data);
    var surcharge = 0.0;
    if (departure != null) {
      if (_isNight(departure.hour, rules)) {
        surcharge += base * (rules.nightPercentage / 100);
        applied
            .add('Night pricing +${rules.nightPercentage.toStringAsFixed(0)}%');
      }
      if (rules.weekendEnabled &&
          (departure.weekday == DateTime.saturday ||
              departure.weekday == DateTime.sunday)) {
        surcharge += base * (rules.weekendPercentage / 100);
        applied.add('Weekend +${rules.weekendPercentage.toStringAsFixed(0)}%');
      }
      if (rules.lastMinuteEnabled &&
          departure.difference(DateTime.now()).inHours <
              rules.lastMinuteWithinHours) {
        surcharge += base * (rules.lastMinutePercentage / 100);
        applied.add(
            'Last minute +${rules.lastMinutePercentage.toStringAsFixed(0)}%');
      }
      if (rules.seasonalEnabled) {
        surcharge += base * (rules.seasonalPercentage / 100);
        applied
            .add('Seasonal +${rules.seasonalPercentage.toStringAsFixed(0)}%');
      }
    }

    final subtotal = base + surcharge;
    final discount = promoDiscount.clamp(0, subtotal).toDouble();
    return PriceEstimate(
      basePrice: base,
      dynamicSurcharge: surcharge,
      discount: discount,
      total: subtotal - discount,
      appliedRules: applied,
    );
  }

  PriceEstimate preview(BookingData data, PricingRules rules) {
    return estimate(
      data: data,
      vehicle: HomeData.vehicles.length > 1
          ? HomeData.vehicles[1]
          : HomeData.vehicles.first,
      rules: rules,
    );
  }

  bool respectsMinimumBooking(BookingData data, PricingRules rules) {
    final departure = departureDateTime(data);
    if (departure == null) return true;
    return departure.difference(DateTime.now()).inMinutes >=
        rules.minimumBookingHours * 60;
  }

  bool canChangeBooking(String date, String time, int limitHours) {
    final departure = departureDateTime(
        BookingData(departureDate: date, departureTime: time));
    if (departure == null) return true;
    return departure.difference(DateTime.now()).inHours >= limitHours;
  }

  DateTime? departureDateTime(BookingData data) {
    if (data.departureDate.isEmpty || data.departureTime.isEmpty) return null;
    for (final format in [
      DateFormat('yyyy-MM-dd h:mm a'),
      DateFormat('yyyy-MM-dd HH:mm'),
    ]) {
      try {
        return format.parse('${data.departureDate} ${data.departureTime}');
      } catch (_) {
        // Try the next common mobile time format.
      }
    }
    return null;
  }

  bool _isNight(int hour, PricingRules rules) {
    if (!rules.nightEnabled) return false;
    if (rules.nightStartHour > rules.nightEndHour) {
      return hour >= rules.nightStartHour || hour < rules.nightEndHour;
    }
    return hour >= rules.nightStartHour && hour < rules.nightEndHour;
  }
}
