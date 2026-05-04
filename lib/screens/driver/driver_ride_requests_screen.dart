import 'package:flutter/material.dart';

import '../../widgets/driver/trip_card.dart';

class DriverRideRequestsScreen extends StatelessWidget {
  const DriverRideRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = [
      const _RequestData(
        clientName: 'Jean Dupont',
        pickup: 'Tunis Carthage Airport (TUN)',
        destination: 'Four Seasons Hotel, Gammarth',
        time: 'Today, 14:30',
        passengerCount: '2 Pax',
        vehicleType: 'Mercedes S-Class',
        estimatedEarnings: '\$85.00',
        vip: true,
      ),
      const _RequestData(
        clientName: 'Sarah Jenkins',
        pickup: 'Movenpick Hotel, Lac 1',
        destination: 'La Marsa Resort',
        time: 'Today, 16:00',
        passengerCount: '3 Pax',
        vehicleType: 'BMW 7 Series',
        estimatedEarnings: '\$40.00',
      ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
        children: [
          const Text(
            'Ride Requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '2 new requests nearby',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          for (final request in requests) ...[
            TripCard(
              clientName: request.clientName,
              pickup: request.pickup,
              destination: request.destination,
              time: request.time,
              passengerCount: request.passengerCount,
              vehicleType: request.vehicleType,
              estimatedEarnings: request.estimatedEarnings,
              vip: request.vip,
              onAccept: () {},
              onReject: () {},
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _RequestData {
  final String clientName;
  final String pickup;
  final String destination;
  final String time;
  final String passengerCount;
  final String vehicleType;
  final String estimatedEarnings;
  final bool vip;

  const _RequestData({
    required this.clientName,
    required this.pickup,
    required this.destination,
    required this.time,
    required this.passengerCount,
    required this.vehicleType,
    required this.estimatedEarnings,
    this.vip = false,
  });
}
