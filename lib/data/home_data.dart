import '../models/popular_route_item.dart';
import '../models/vehicle.dart';

class TrustChipItem {
  final String title;
  final String value;
  final int iconCodePoint; // Material icon code point for lightweight model

  const TrustChipItem({
    required this.title,
    required this.value,
    required this.iconCodePoint,
  });
}

class HowItWorksItem {
  final int step;
  final String title;
  final String desc;
  final int iconCodePoint;
  final int bgColor;
  final int iconColor;

  const HowItWorksItem({
    required this.step,
    required this.title,
    required this.desc,
    required this.iconCodePoint,
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
      iconCodePoint: 0xe491, // verified_user_outlined
    ),
    TrustChipItem(
      title: 'Fixed Pricing',
      value: 'No meters',
      iconCodePoint: 0xe8f6, // sell_outlined
    ),
    TrustChipItem(
      title: '24/7 Support',
      value: 'Always on',
      iconCodePoint: 0xe192, // schedule
    ),
    TrustChipItem(
      title: 'Flight Tracking',
      value: 'Real-time',
      iconCodePoint: 0xe539, // flight_takeoff
    ),
  ];

  static const howItWorks = [
    HowItWorksItem(
      step: 1,
      title: 'Choose route',
      desc: 'Enter pickup & destination',
      iconCodePoint: 0xe55f, // place_outlined
      bgColor: 0xFFEBF4FF,
      iconColor: 0xFF4A90D9,
    ),
    HowItWorksItem(
      step: 2,
      title: 'Pick vehicle',
      desc: 'Select your preferred class',
      iconCodePoint: 0xe531, // directions_car
      bgColor: 0xFFFFF8E6,
      iconColor: 0xFFE6A200,
    ),
    HowItWorksItem(
      step: 3,
      title: 'Confirm & relax',
      desc: 'Driver meets you on time',
      iconCodePoint: 0xe86c, // check_circle_outline
      bgColor: 0xFFF0FFF4,
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
      image: 'https://images.unsplash.com/photo-1665083767053-5e7ad680953d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800',
    ),
    PopularRouteItem(
      id: 2,
      from: 'Tunis-Carthage',
      to: 'Hammamet',
      price: 75,
      time: '55 min',
      image: 'https://images.unsplash.com/photo-1751970187302-b997b6c269db?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800',
    ),
    PopularRouteItem(
      id: 3,
      from: 'Monastir Airport',
      to: 'Sousse',
      price: 35,
      time: '30 min',
      image: 'https://images.unsplash.com/photo-1653173449794-09b4ec96a17f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800',
    ),
    PopularRouteItem(
      id: 4,
      from: 'Djerba Airport',
      to: 'Djerba Town',
      price: 25,
      time: '20 min',
      image: 'https://images.unsplash.com/photo-1689000620187-173b08472ba3?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800',
    ),
  ];

  static const vehicles = [
    Vehicle(
      id: 1,
      name: 'Mercedes E-Class 2024',
      model: 'Executive sedan',
      capacity: '1–3',
      bags: 3,
      label: 'Popular',
      labelGold: true,
      price: 30,
      image: 'assets/images/fleet/mercedes-e-class-2024-carthage-transfer.webp',
    ),
    Vehicle(
      id: 2,
      name: 'Mercedes V-Class VIP',
      model: 'Luxury van',
      capacity: '1–7',
      bags: 6,
      label: 'Premium',
      labelGold: false,
      price: 55,
      image: 'assets/images/fleet/Mercedes-V-Class-Vip-Transfers-Tunisia.webp',
    ),
    Vehicle(
      id: 3,
      name: 'Toyota Hiace',
      model: 'Premium shuttle',
      capacity: '1–12',
      bags: 10,
      label: 'Elite',
      labelGold: false,
      price: 90,
      image: 'assets/images/fleet/Toyota-Hiace-Transfers-Tunisia.webp',
    ),
    Vehicle(
      id: 4,
      name: 'Toyota Coaster',
      model: 'Executive coach',
      capacity: '1–18',
      bags: 18,
      label: 'Group',
      labelGold: false,
      price: 70,
      image: 'assets/images/fleet/Toyota-Coaster-Transfers-Tunisia.webp',
    ),
    Vehicle(
      id: 5,
      name: 'Land Cruiser Prado',
      model: 'Premium SUV',
      capacity: '1–5',
      bags: 5,
      label: 'SUV',
      labelGold: false,
      price: 80,
      image: 'assets/images/fleet/landcruiser-prado.webp',
    ),
  ];
}
