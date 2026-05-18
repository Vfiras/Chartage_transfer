import 'package:flutter/material.dart';

import '../models/popular_route_item.dart';
import '../models/vehicle.dart';

class TrustChipItem {
  final String title;
  final String value;
  final IconData icon;

  const TrustChipItem({
    required this.title,
    required this.value,
    required this.icon,
  });
}

class HowItWorksItem {
  final int step;
  final String title;
  final String desc;
  final IconData icon;
  final int bgColor;
  final int iconColor;

  const HowItWorksItem({
    required this.step,
    required this.title,
    required this.desc,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}

class HomeData {
  static const partnerLogos = [
    'assets/images/partners/Lufthansa-Logo.webp',
    'assets/images/partners/OAI-LOGO.webp',
    'assets/images/partners/tunisair-logo.webp',
    'assets/images/partners/Turkish_Airlines-logo-800x289.webp',
    'assets/images/partners/viatovia.webp',
    'assets/images/partners/ysf-partner.webp',
  ];

  static const trustChips = [
    TrustChipItem(
        title: 'Licensed Drivers',
        value: '100%',
        icon: Icons.verified_user_outlined),
    TrustChipItem(
        title: 'Fixed Pricing', value: 'No meters', icon: Icons.sell_outlined),
    TrustChipItem(
        title: '24/7 Support',
        value: 'Always on',
        icon: Icons.schedule_rounded),
    TrustChipItem(
        title: 'Premium Fleet',
        value: '6 classes',
        icon: Icons.directions_car_rounded),
  ];

  static const howItWorks = [
    HowItWorksItem(
      step: 1,
      title: 'Choose route',
      desc: 'Enter pickup and destination',
      icon: Icons.place_outlined,
      bgColor: 0x22D4AF37,
      iconColor: 0xFFD4AF37,
    ),
    HowItWorksItem(
      step: 2,
      title: 'Pick vehicle',
      desc: 'Select your preferred class',
      icon: Icons.directions_car_rounded,
      bgColor: 0x22D4AF37,
      iconColor: 0xFFD4AF37,
    ),
    HowItWorksItem(
      step: 3,
      title: 'Confirm ride',
      desc: 'Review details and book',
      icon: Icons.check_circle_outline_rounded,
      bgColor: 0x2227AE60,
      iconColor: 0xFF27AE60,
    ),
  ];

  static const popularRoutes = [
    PopularRouteItem(
      id: 1,
      from: 'Tunis-Carthage',
      to: 'City Centre',
      price: 30,
      time: '25 min',
      image:
          'https://images.unsplash.com/photo-1665083767053-5e7ad680953d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800',
    ),
    PopularRouteItem(
      id: 2,
      from: 'Tunis-Carthage',
      to: 'Hammamet',
      price: 75,
      time: '55 min',
      image:
          'https://images.unsplash.com/photo-1751970187302-b997b6c269db?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800',
    ),
    PopularRouteItem(
      id: 3,
      from: 'Monastir Airport',
      to: 'Sousse',
      price: 35,
      time: '30 min',
      image:
          'https://images.unsplash.com/photo-1653173449794-09b4ec96a17f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800',
    ),
    PopularRouteItem(
      id: 4,
      from: 'Djerba Airport',
      to: 'Djerba Town',
      price: 25,
      time: '20 min',
      image:
          'https://images.unsplash.com/photo-1689000620187-173b08472ba3?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800',
    ),
  ];

  static const vehicles = [
    Vehicle(
      id: 1,
      name: 'Standard',
      model: 'Comfort sedan',
      capacity: '4 seats',
      bags: 2,
      label: 'Standard',
      labelGold: true,
      price: 18,
      image:
          'assets/images/fleet/Renault-Express-Minivan-Transfers-Tunisia.webp',
      seats: 4,
      category: 'Standard',
    ),
    Vehicle(
      id: 2,
      name: 'VIP',
      model: 'Executive sedan',
      capacity: '3 seats',
      bags: 2,
      label: 'VIP',
      labelGold: false,
      price: 28,
      image: 'assets/images/fleet/mercedes-e-class-2024-carthage-transfer.webp',
      seats: 3,
      category: 'VIP',
    ),
    Vehicle(
      id: 3,
      name: 'Luxury',
      model: 'Premium class',
      capacity: '3 seats',
      bags: 2,
      label: 'Luxury',
      labelGold: false,
      price: 40,
      image: 'assets/images/fleet/premium-sedan-2024-carthage-transfer.webp',
      seats: 3,
      category: 'Luxury',
    ),
    Vehicle(
      id: 5,
      name: 'Van',
      model: 'Premium van',
      capacity: '7 seats',
      bags: 5,
      label: 'Group',
      labelGold: false,
      price: 50,
      image: 'assets/images/fleet/Mercedes-V-Class-Vip-Transfers-Tunisia.webp',
      seats: 7,
      category: 'Van',
    ),
  ];
}
