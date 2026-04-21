import '../models/fleet_item.dart';

class FleetData {
  static const categories = ['All', 'Sedan', 'SUV', 'Limousine', 'Van'];

  static const items = [
    FleetItem(
      id: 1,
      name: 'Business Sedan',
      model: 'Mercedes E-Class or similar',
      category: 'Sedan',
      pax: 3,
      bags: 3,
      comfort: 'Comfort',
      features: ['WiFi on request', 'Air conditioning', 'Professional driver'],
      price: 'From 30 TND',
      image: 'https://images.unsplash.com/photo-1767285610734-f0858d5248fe?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1000',
    ),
    FleetItem(
      id: 2,
      name: 'Executive SUV',
      model: 'BMW X5 / Mercedes GLE',
      category: 'SUV',
      pax: 6,
      bags: 5,
      comfort: 'Premium',
      features: ['Spacious cabin', 'Luggage assist', 'Meet & greet'],
      price: 'From 55 TND',
      image: 'https://images.unsplash.com/photo-1767749995450-7b63ab7cd4fd?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1000',
    ),
    FleetItem(
      id: 3,
      name: 'VIP Limousine',
      model: 'Mercedes S-Class',
      category: 'Limousine',
      pax: 3,
      bags: 2,
      comfort: 'Elite',
      features: ['Premium leather', 'Champagne welcome', 'Name-board pickup'],
      price: 'From 90 TND',
      image: 'https://images.unsplash.com/photo-1771775751121-3091d79073d4?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1000',
    ),
    FleetItem(
      id: 4,
      name: 'Premium Van',
      model: 'Mercedes V-Class',
      category: 'Van',
      pax: 8,
      bags: 8,
      comfort: 'Group',
      features: ['Group friendly', 'Extra luggage space', 'Child seats available'],
      price: 'From 70 TND',
      image: 'https://images.unsplash.com/photo-1750210505997-ed85e9f8cb12?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1000',
    ),
  ];
}