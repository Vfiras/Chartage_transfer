import '../models/popular_route_item.dart';

class DestinationsData {
  static const filters = ['All', 'Tunis', 'Monastir', 'Djerba', 'Hammamet'];

  static const routes = [
    PopularRouteItem(
      id: 1,
      from: 'Tunis-Carthage Airport',
      to: 'Tunis City Centre',
      price: 30,
      time: '25 min',
      image: 'https://images.unsplash.com/photo-1665083767053-5e7ad680953d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800',
    ),
    PopularRouteItem(
      id: 2,
      from: 'Tunis-Carthage Airport',
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
      to: 'Djerba Town Centre',
      price: 25,
      time: '20 min',
      image: 'https://images.unsplash.com/photo-1689000620187-173b08472ba3?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=800',
    ),
  ];
}