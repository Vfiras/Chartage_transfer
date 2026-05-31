import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'transport_trip.dart';

// Backend canonical statuses: pending | confirmed | on_route | completed | cancelled
enum AdminBookingStatus { pending, confirmed, onRoute, completed, cancelled }

extension AdminBookingStatusX on AdminBookingStatus {
  String get label => switch (this) {
        AdminBookingStatus.pending => 'Pending',
        AdminBookingStatus.confirmed => 'Confirmed',
        AdminBookingStatus.onRoute => 'On Route',
        AdminBookingStatus.completed => 'Completed',
        AdminBookingStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        AdminBookingStatus.pending => AppColors.secondary,
        AdminBookingStatus.confirmed => const Color(0xFF55D17A),
        AdminBookingStatus.onRoute => const Color(0xFF4A90D9),
        AdminBookingStatus.completed => const Color(0xFF6F9CFF),
        AdminBookingStatus.cancelled => const Color(0xFFFF7A7A),
      };

  // Raw backend string (sent to API)
  String get rawValue => switch (this) {
        AdminBookingStatus.pending => 'pending',
        AdminBookingStatus.confirmed => 'confirmed',
        AdminBookingStatus.onRoute => 'on_route',
        AdminBookingStatus.completed => 'completed',
        AdminBookingStatus.cancelled => 'cancelled',
      };

  static AdminBookingStatus fromRaw(String raw) => switch (raw) {
        'pending' => AdminBookingStatus.pending,
        'confirmed' => AdminBookingStatus.confirmed,
        'on_route' => AdminBookingStatus.onRoute,
        'completed' => AdminBookingStatus.completed,
        'cancelled' => AdminBookingStatus.cancelled,
        _ => AdminBookingStatus.pending,
      };
}

class AdminBooking {
  final String reference;
  final String pickupDateTime;
  final String source;
  final String destination;
  final String supplierName;
  final String price;
  final String paymentMethod;
  final String clientName;
  final String clientPhone;
  final String route;
  final String statusText;
  final String notes;
  final AdminBookingStatus status;

  // Extended fields for details screen
  final String departureDate;
  final String departureTime;
  final int passengerCount;
  final int luggageCount;
  final String vehicleType;
  final String contactEmail;

  const AdminBooking({
    required this.reference,
    required this.pickupDateTime,
    required this.source,
    required this.destination,
    required this.supplierName,
    required this.price,
    required this.paymentMethod,
    required this.clientName,
    required this.clientPhone,
    required this.route,
    required this.statusText,
    required this.notes,
    required this.status,
    this.departureDate = '',
    this.departureTime = '',
    this.passengerCount = 1,
    this.luggageCount = 0,
    this.vehicleType = '',
    this.contactEmail = '',
  });

  AdminBooking copyWithStatus(AdminBookingStatus newStatus) => AdminBooking(
        reference: reference,
        pickupDateTime: pickupDateTime,
        source: source,
        destination: destination,
        supplierName: supplierName,
        price: price,
        paymentMethod: paymentMethod,
        clientName: clientName,
        clientPhone: clientPhone,
        route: route,
        statusText: newStatus.label,
        notes: notes,
        status: newStatus,
        departureDate: departureDate,
        departureTime: departureTime,
        passengerCount: passengerCount,
        luggageCount: luggageCount,
        vehicleType: vehicleType,
        contactEmail: contactEmail,
      );

  factory AdminBooking.fromTrip(TransportTrip trip) {
    final status = AdminBookingStatusX.fromRaw(trip.status);
    final dateLabel = trip.departureDate.isNotEmpty
        ? trip.departureDate
        : trip.pickupTime;
    final timeLabel = trip.departureTime.isNotEmpty
        ? trip.departureTime
        : trip.pickupTime;
    final priceVal = trip.totalPrice > 0
        ? trip.totalPrice
        : trip.estimatedEarnings;

    return AdminBooking(
      reference: trip.id,
      pickupDateTime: '${trip.departureDate} ${trip.departureTime}'.trim(),
      source: trip.pickupLocation,
      destination: trip.destinationName,
      supplierName: trip.driverId ?? 'Unassigned',
      price: '\$${priceVal.toStringAsFixed(2)}',
      paymentMethod: 'Operations',
      clientName: trip.passengerName,
      clientPhone: trip.passengerPhone,
      route: '${trip.pickupLocation} → ${trip.destinationName}',
      statusText: status.label,
      notes: 'Booking ID: ${trip.id}',
      status: status,
      departureDate: dateLabel,
      departureTime: timeLabel,
      passengerCount: trip.passengerCount,
      luggageCount: trip.luggageCount,
      vehicleType: trip.vehicleClass.isNotEmpty ? trip.vehicleClass : trip.vehicleType,
      contactEmail: trip.contactEmail,
    );
  }

  static const sampleData = [
    AdminBooking(
      reference: 'BK-7829',
      pickupDateTime: '2024-05-15 14:30',
      source: 'Tunis Carthage Airport (TUN)',
      destination: 'Hammamet, Tunisia',
      supplierName: 'Elite Transfers',
      price: '\$120.00',
      paymentMethod: 'Credit Card',
      clientName: 'John Doe',
      clientPhone: '+216 22 123 456',
      route: 'Airport → Hotel',
      statusText: 'Confirmed',
      notes: 'VIP airport pickup with luggage assistance.',
      status: AdminBookingStatus.confirmed,
      departureDate: '2024-05-15',
      departureTime: '14:30',
      passengerCount: 2,
      luggageCount: 3,
      vehicleType: 'Executive Sedan',
    ),
    AdminBooking(
      reference: 'BK-7830',
      pickupDateTime: '2024-05-15 16:45',
      source: 'Sousse',
      destination: 'Monastir Airport (MIR)',
      supplierName: 'Premium Rides',
      price: '\$45.00',
      paymentMethod: 'Cash',
      clientName: 'Sarah Smith',
      clientPhone: '+216 55 987 654',
      route: 'City → Airport',
      statusText: 'Pending',
      notes: 'Awaiting supplier assignment.',
      status: AdminBookingStatus.pending,
      departureDate: '2024-05-15',
      departureTime: '16:45',
      passengerCount: 1,
      luggageCount: 1,
      vehicleType: 'Business Van',
    ),
  ];
}
