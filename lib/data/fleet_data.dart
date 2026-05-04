import '../models/fleet_item.dart';

class FleetData {
  static const categories = ['All', 'Sedan', 'SUV', 'Limousine', 'Van'];

  static const items = [
    FleetItem(
      id: 1,
      name: 'Mercedes E-Class 2024',
      model: 'Executive sedan',
      category: 'Sedan',
      pax: 3,
      bags: 3,
      comfort: 'Premium',
      features: ['WiFi on request', 'Air conditioning', 'Professional driver'],
      price: 'From 30 TND',
      image: 'assets/images/fleet/mercedes-e-class-2024-carthage-transfer.webp',
    ),
    FleetItem(
      id: 2,
      name: 'Mercedes V-Class VIP',
      model: 'Luxury van',
      category: 'Van',
      pax: 7,
      bags: 6,
      comfort: 'Elite',
      features: ['Spacious cabin', 'Luggage assist', 'Meet & greet'],
      price: 'From 55 TND',
      image: 'assets/images/fleet/Mercedes-V-Class-Vip-Transfers-Tunisia.webp',
    ),
    FleetItem(
      id: 3,
      name: 'Toyota Hiace',
      model: 'Premium shuttle',
      category: 'Van',
      pax: 12,
      bags: 10,
      comfort: 'Group',
      features: ['Premium leather', 'Champagne welcome', 'Name-board pickup'],
      price: 'From 90 TND',
      image: 'assets/images/fleet/Toyota-Hiace-Transfers-Tunisia.webp',
    ),
    FleetItem(
      id: 4,
      name: 'Toyota Coaster',
      model: 'Executive coach',
      category: 'Van',
      pax: 18,
      bags: 18,
      comfort: 'Group',
      features: ['Group friendly', 'Extra luggage space', 'Child seats available'],
      price: 'From 70 TND',
      image: 'assets/images/fleet/Toyota-Coaster-Transfers-Tunisia.webp',
    ),
    FleetItem(
      id: 5,
      name: 'Land Cruiser Prado',
      model: 'Premium SUV',
      category: 'SUV',
      pax: 5,
      bags: 5,
      comfort: 'Premium',
      features: ['Luxury interior', 'All-terrain comfort', 'VIP service'],
      price: 'From 80 TND',
      image: 'assets/images/fleet/landcruiser-prado.webp',
    ),
  ];
}
