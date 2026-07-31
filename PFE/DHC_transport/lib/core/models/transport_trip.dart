class TransportTrip {
  final String id;
  final String? driverId;
  final String passengerName;
  final String passengerPhone;
  final String pickupLocation;
  final String destinationName;
  final String destinationCity;
  final String vehicleType;
  final double estimatedEarnings;
  final String pickupTime;
  final String status;
  final int etaMinutes;
  final String tripType;
  final String departureDate;
  final String departureTime;
  final String returnDate;
  final String returnTime;
  final int passengerCount;
  final int luggageCount;
  final String promoCode;
  final double dynamicSurcharge;
  final double discountAmount;
  final String contactEmail;
  final String contactPhone;
  final String vehicleClass;
  final double totalPrice;
  final String paymentMethod; // cash | card
  final String paymentStatus; // pending_approval | approved | pending_payment

  const TransportTrip({
    required this.id,
    required this.driverId,
    required this.passengerName,
    required this.passengerPhone,
    required this.pickupLocation,
    required this.destinationName,
    required this.destinationCity,
    required this.vehicleType,
    required this.estimatedEarnings,
    required this.pickupTime,
    required this.status,
    required this.etaMinutes,
    required this.tripType,
    required this.departureDate,
    required this.departureTime,
    required this.returnDate,
    required this.returnTime,
    required this.passengerCount,
    required this.luggageCount,
    required this.promoCode,
    required this.dynamicSurcharge,
    required this.discountAmount,
    required this.contactEmail,
    required this.contactPhone,
    required this.vehicleClass,
    required this.totalPrice,
    this.paymentMethod = 'cash',
    this.paymentStatus = 'approved',
  });

  factory TransportTrip.fromJson(Map<String, dynamic> json) {
    return TransportTrip(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      driverId: json['driver_id']?.toString(),
      passengerName: json['passenger_name']?.toString() ?? 'Passenger',
      passengerPhone: json['passenger_phone']?.toString() ?? '',
      pickupLocation: json['pickup_location']?.toString() ?? 'Pickup location',
      destinationName: json['destination_name']?.toString() ?? 'Destination',
      destinationCity: json['destination_city']?.toString() ?? '',
      vehicleType: json['vehicle_type']?.toString() ?? 'Executive vehicle',
      estimatedEarnings: (json['estimated_earnings'] as num?)?.toDouble() ?? 0,
      pickupTime: json['pickup_time']?.toString() ?? '',
      status: json['status']?.toString() ?? 'requested',
      etaMinutes: (json['eta_minutes'] as num?)?.toInt() ?? 12,
      tripType: json['trip_type']?.toString() ?? 'one-way',
      departureDate: json['departure_date']?.toString() ?? '',
      departureTime: json['departure_time']?.toString() ??
          json['pickup_time']?.toString() ??
          '',
      returnDate: json['return_date']?.toString() ?? '',
      returnTime: json['return_time']?.toString() ?? '',
      passengerCount: (json['passenger_count'] as num?)?.toInt() ?? 1,
      luggageCount: (json['luggage_count'] as num?)?.toInt() ?? 1,
      promoCode: json['promo_code']?.toString() ?? '',
      dynamicSurcharge: (json['dynamic_surcharge'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      contactEmail: json['contact_email']?.toString() ??
          json['guest_email']?.toString() ??
          '',
      contactPhone: json['contact_phone']?.toString() ??
          json['guest_phone']?.toString() ??
          json['passenger_phone']?.toString() ??
          '',
      vehicleClass: json['vehicle_class']?.toString() ??
          json['vehicle_type']?.toString() ??
          '',
      totalPrice: (json['total_price'] as num?)?.toDouble() ??
          (json['estimated_earnings'] as num?)?.toDouble() ??
          0,
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      // Older bookings predate the payment flow — treat them as approved.
      paymentStatus: json['payment_status']?.toString() ?? 'approved',
    );
  }

  bool get isPendingApproval => paymentStatus == 'pending_approval';

  String get earningsLabel => '\$${estimatedEarnings.toStringAsFixed(2)}';
}
