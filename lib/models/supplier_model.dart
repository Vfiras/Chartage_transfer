import 'package:flutter/material.dart';

enum SupplierStatus { active, inactive, suspended }

extension SupplierStatusX on SupplierStatus {
  String get label => switch (this) {
        SupplierStatus.active => 'Active',
        SupplierStatus.inactive => 'Inactive',
        SupplierStatus.suspended => 'Suspended',
      };

  Color get color => switch (this) {
        SupplierStatus.active => const Color(0xFF55D17A),
        SupplierStatus.inactive => const Color(0xFF9A9A9A),
        SupplierStatus.suspended => const Color(0xFFFF7A7A),
      };
}

class SupplierModel {
  final String name;
  final String phone;
  final String email;
  final String handle;
  final SupplierStatus status;
  final IconData icon;

  const SupplierModel({
    required this.name,
    required this.phone,
    required this.email,
    required this.handle,
    required this.status,
    required this.icon,
  });

  static const sampleData = [
    SupplierModel(
      name: 'Elite Transfers',
      phone: '+216 22 123 456',
      email: 'contact@elitetransfers.tn',
      handle: '@elite_tunis',
      status: SupplierStatus.active,
      icon: Icons.directions_car_rounded,
    ),
    SupplierModel(
      name: 'Premium Rides',
      phone: '+216 55 987 654',
      email: 'info@premiumrides.tn',
      handle: '@premium_rides',
      status: SupplierStatus.active,
      icon: Icons.local_taxi_rounded,
    ),
    SupplierModel(
      name: 'Carthage VIP',
      phone: '+216 98 111 222',
      email: 'vip@carthage.tn',
      handle: '@carthage_vip',
      status: SupplierStatus.inactive,
      icon: Icons.airport_shuttle_rounded,
    ),
    SupplierModel(
      name: 'Airport Shuttle Pro',
      phone: '+216 23 444 555',
      email: 'hello@shuttlepro.tn',
      handle: '@shuttle_pro',
      status: SupplierStatus.active,
      icon: Icons.directions_bus_rounded,
    ),
    SupplierModel(
      name: 'Tunis Limo Service',
      phone: '+216 50 777 888',
      email: 'bookings@tunislimo.tn',
      handle: '@tunis_limo',
      status: SupplierStatus.suspended,
      icon: Icons.directions_bus_rounded,
    ),
  ];
}
