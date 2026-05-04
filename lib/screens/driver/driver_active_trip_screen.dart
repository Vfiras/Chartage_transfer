import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/driver/driver_action_button.dart';

class DriverActiveTripScreen extends StatelessWidget {
  const DriverActiveTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
        children: [
          _RouteHeaderCard(
            title: 'Continue on N9 Route',
            subtitle: '2.4 km • Towards Gammarth',
          ),
          const SizedBox(height: 14),
          _MapPlaceholder(
            etaLabel: '12 min',
            driverLabel: 'Driver Location',
            pickupLabel: 'Pickup',
            destinationLabel: 'Destination',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF494949),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'EN ROUTE TO PICKUP',
                  style: TextStyle(
                    color: Color(0xFF7D7D7D),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '12',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w300,
                        height: 0.95,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'min',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0E0E0E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.navigation_rounded,
                          color: AppColors.secondary, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '8.5 km • ETA 14:42',
                  style: TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Color(0xFF0E0E0E),
                      child: Icon(Icons.person_outline_rounded,
                          color: Color(0xFF8C8C8C)),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jean Dupont',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'VIP CLIENT • ★ 4.9',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CircleIconButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      color: const Color(0xFF2B2B2B),
                      iconColor: Colors.white,
                      onTap: () {},
                    ),
                    const SizedBox(width: 10),
                    _CircleIconButton(
                      icon: Icons.call_rounded,
                      color: const Color(0xFF173120),
                      iconColor: const Color(0xFF67E28C),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101010),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0x1FFFFFFF)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.place_outlined,
                          color: AppColors.secondary, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PICKUP LOCATION',
                              style: TextStyle(
                                color: Color(0xFF828282),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Tunis Carthage Airport (TUN)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: DriverActionButton(
                        label: 'Start trip',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () {},
                        variant: DriverActionButtonVariant.gold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DriverActionButton(
                        label: 'End trip',
                        icon: Icons.stop_rounded,
                        onPressed: () {},
                        variant: DriverActionButtonVariant.dark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DriverActionButton(
                  label: 'Contact client',
                  icon: Icons.chat_rounded,
                  onPressed: () {},
                  variant: DriverActionButtonVariant.success,
                ),
                const SizedBox(height: 10),
                DriverActionButton(
                  label: 'Tap when Arrived',
                  onPressed: () {},
                  variant: DriverActionButtonVariant.light,
                  height: 58,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _RouteHeaderCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0x332E2E2E),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded,
                color: AppColors.secondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8C8C8C),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  final String etaLabel;
  final String driverLabel;
  final String pickupLabel;
  final String destinationLabel;

  const _MapPlaceholder({
    required this.etaLabel,
    required this.driverLabel,
    required this.pickupLabel,
    required this.destinationLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 340,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF160B0B), Color(0xFF0E0E0E), Color(0xFF171717)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    center: Alignment(-0.1, -0.5),
                    radius: 1.2,
                    colors: [
                      Color(0x44E6A200),
                      Color(0x11000000),
                      Color(0x00000000),
                    ],
                  ),
                  border: Border.all(color: const Color(0x0AFFFFFF)),
                ),
              ),
            ),
            Positioned(
              left: 18,
              top: 18,
              right: 18,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xDD171717),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0x332E2E2E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.navigation_rounded,
                          color: AppColors.secondary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Driver location marker',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$pickupLabel • $destinationLabel',
                            style: const TextStyle(
                              color: Color(0xFF9D9D9D),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 96,
              top: 124,
              child: _MapPin(label: pickupLabel, color: AppColors.secondary),
            ),
            Positioned(
              right: 60,
              top: 176,
              child: _MapPin(label: destinationLabel, color: const Color(0xFF59D47B)),
            ),
            Positioned(
              left: 58,
              top: 154,
              child: _RouteCurve(),
            ),
            Positioned(
              left: 120,
              top: 236,
              child: _MapPin(
                label: driverLabel,
                color: const Color(0xFF6F9CFF),
                isDriver: true,
              ),
            ),
            Positioned(
              left: 126,
              top: 250,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.14),
                  border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xDD141414),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F0F0F),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer_outlined,
                          color: AppColors.secondary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$etaLabel route progress',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Placeholder map layout ready for Google Maps integration',
                            style: TextStyle(
                              color: Color(0xFF949494),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDriver;

  const _MapPin({
    required this.label,
    required this.color,
    this.isDriver = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: isDriver ? 18 : 14,
          height: isDriver ? 18 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xCC111111),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteCurve extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(120, 90),
      painter: _RoutePainter(),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(8, 20)
      ..quadraticBezierTo(size.width * 0.48, 6, size.width - 12, size.height - 16);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
