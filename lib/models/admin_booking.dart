import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AdminBookingStatus { confirmed, pending, completed, cancelled }

extension AdminBookingStatusX on AdminBookingStatus {
  String get label => switch (this) {
        AdminBookingStatus.confirmed => 'Confirmed',
        AdminBookingStatus.pending => 'Pending',
        AdminBookingStatus.completed => 'Completed',
        AdminBookingStatus.cancelled => 'Cancelled',
      };

  Color get color => switch (this) {
        AdminBookingStatus.confirmed => const Color(0xFF55D17A),
        AdminBookingStatus.pending => AppColors.secondary,
        AdminBookingStatus.completed => const Color(0xFF6F9CFF),
        AdminBookingStatus.cancelled => const Color(0xFFFF7A7A),
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
  });

  static const sampleData = [
    AdminBooking(
      reference: 'BK-7829',
      pickupDateTime: '2024-05-15 - 14:30',
      source: 'Tunis Carthage Airport (TUN)',
      destination: 'Hammamet, Tunisia',
      supplierName: 'Elite Transfers',
      price: '\$120.00',
      paymentMethod: 'Credit Card (Stripe)',
      clientName: 'John Doe',
      clientPhone: '+216 22 123 456',
      route: 'Airport to Hotel',
      statusText: 'Confirmed',
      notes: 'VIP airport pickup with luggage assistance and meet-and-greet service.',
      status: AdminBookingStatus.confirmed,
    ),
    AdminBooking(
      reference: 'BK-7830',
      pickupDateTime: '2024-05-15 - 16:45',
      source: 'Sousse',
      destination: 'Monastir Airport (MIR)',
      supplierName: 'Premium Rides',
      price: '\$45.00',
      paymentMethod: 'Cash on Delivery',
      clientName: 'Sarah Smith',
      clientPhone: '+216 55 987 654',
      route: 'City to Airport',
      statusText: 'Pending',
      notes: 'Standard transfer awaiting supplier assignment.',
      status: AdminBookingStatus.pending,
    ),
    AdminBooking(
      reference: 'BK-7831',
      pickupDateTime: '2024-05-15 - 18:10',
      source: 'La Marsa',
      destination: 'Tunis Downtown',
      supplierName: 'Carthage VIP',
      price: '\$85.00',
      paymentMethod: 'Apple Pay',
      clientName: 'Mouna Ben Ali',
      clientPhone: '+216 98 111 222',
      route: 'Hotel to City',
      statusText: 'Completed',
      notes: 'Completed with no incidents.',
      status: AdminBookingStatus.completed,
    ),
  ];
}
