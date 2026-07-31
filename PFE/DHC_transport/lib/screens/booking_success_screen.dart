import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/routing/app_routes.dart';
import '../models/booking_data.dart';
import '../models/vehicle.dart';
import '../widgets/common/fallback_network_image.dart';
import '../widgets/common/luxury_cta.dart';

/// Post-booking screen — the emotional peak of the journey.
///
/// Designed as a first-class ticket, not a form receipt: airport-style route
/// codes, the vehicle on its plate, a perforated ticket fold, and a calm
/// gold checkmark that draws itself in. Gold is reserved for the moment
/// (check), the money (total), the status, and the action (CTA).
class BookingSuccessScreen extends StatefulWidget {
  final String tripId;
  final BookingData data;
  final Vehicle vehicle;
  final double totalPrice;

  const BookingSuccessScreen({
    super.key,
    required this.tripId,
    required this.data,
    required this.vehicle,
    required this.totalPrice,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _check;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    // Motion should be felt, not seen: one 650ms ease-out sequence — ring +
    // content fade first, then the check draws itself. Nothing bounces.
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650));
    _fade = CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
    _check = CurvedAnimation(
        parent: _anim,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.clientShell, (route) => false,
        arguments: 0);
  }

  void _viewRides(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.clientShell, (route) => false,
        arguments: 1);
  }

  String get _shortId {
    final id = widget.tripId;
    if (id.length > 8) return 'CT-${id.substring(0, 8).toUpperCase()}';
    return 'CT-${id.toUpperCase()}';
  }

  /// Cash bookings need admin approval before they're actually confirmed.
  bool get _isPendingApproval => widget.data.paymentMethod == 'cash';

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Gold check — draws itself in ─────────────────────────
                Center(child: _DrawnCheck(progress: _check)),
                const SizedBox(height: 24),

                Text(
                  _isPendingApproval ? 'Booking Received' : 'Booking Confirmed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isPendingApproval
                      ? 'Our team will confirm your transfer shortly.'
                      : 'Your executive chauffeur is scheduled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // ── The ticket ───────────────────────────────────────────
                _TicketCard(
                  data: data,
                  vehicle: widget.vehicle,
                  totalPrice: widget.totalPrice,
                  shortId: _shortId,
                  pendingApproval: _isPendingApproval,
                ),

                if (_isPendingApproval) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_active_outlined,
                          color: Colors.white.withValues(alpha: 0.55),
                          size: 15),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'You\'ll receive a notification once confirmed.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 28),
                LuxuryCta(
                  text: 'View My Rides',
                  icon: Icons.directions_car_rounded,
                  onTap: () => _viewRides(context),
                ),
                const SizedBox(height: 12),
                LuxuryCta(
                  text: 'Return Home',
                  icon: Icons.home_rounded,
                  outlined: true,
                  onTap: () => _goHome(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Ticket card ───────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final BookingData data;
  final Vehicle vehicle;
  final double totalPrice;
  final String shortId;
  final bool pendingApproval;

  const _TicketCard({
    required this.data,
    required this.vehicle,
    required this.totalPrice,
    required this.shortId,
    required this.pendingApproval,
  });

  /// Airport-style 3-letter route codes. Known Tunisian airports first,
  /// then a clean derivation from the place name.
  static String _routeCode(String place) {
    final lower = place.toLowerCase();
    const known = <String, String>{
      'tunis-carthage': 'TUN',
      'carthage airport': 'TUN',
      '(tun)': 'TUN',
      'enfidha': 'NBE',
      '(nbe)': 'NBE',
      'monastir': 'MIR',
      '(mir)': 'MIR',
      'djerba': 'DJE',
      '(dje)': 'DJE',
      'hammamet': 'HAM',
      'sousse': 'SOU',
      'sfax': 'SFX',
      'tunis': 'TNS',
      'la marsa': 'MRS',
      'sidi bou said': 'SBS',
      'nabeul': 'NAB',
      'bizerte': 'BIZ',
    };
    for (final entry in known.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    final letters = place.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    return letters.length >= 3 ? letters.substring(0, 3) : letters.padRight(3, 'X');
  }

  @override
  Widget build(BuildContext context) {
    final quiet = Colors.white.withValues(alpha: 0.60);
    final currency = data.currency.isEmpty ? 'EUR' : data.currency;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // ── Header: brand + status ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'CARTHAGE TRANSFER',
                    style: TextStyle(
                      color: quiet,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        pendingApproval
                            ? Icons.hourglass_top_rounded
                            : Icons.schedule_rounded,
                        color: AppColors.secondary,
                        size: 12,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        pendingApproval ? 'PENDING APPROVAL' : 'SCHEDULED',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Route: airport-code style ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _routeCode(data.pickup),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.pickup,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: quiet, fontSize: 11, height: 1.35),
                      ),
                    ],
                  ),
                ),
                // Route line with car glyph
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: 86,
                    child: Row(
                      children: [
                        _routeDot(),
                        Expanded(child: _routeLine()),
                        Icon(Icons.directions_car_rounded,
                            color: AppColors.secondary, size: 16),
                        Expanded(child: _routeLine()),
                        _routeDot(),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _routeCode(data.destination),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.destination,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: quiet, fontSize: 11, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Vehicle plate ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 116,
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FallbackNetworkImage(
                  url: vehicle.image,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            vehicle.name,
            style: TextStyle(
              color: quiet,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 16),

          // ── Perforated fold ──────────────────────────────────────────
          _TicketPerforation(background: AppColors.background),

          // ── Details grid ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _TicketField(
                            label: 'DATE', value: data.departureDate)),
                    Expanded(
                        child: _TicketField(
                            label: 'PICKUP TIME',
                            value: data.departureTime,
                            alignEnd: true)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                        child: _TicketField(
                            label: 'PASSENGERS',
                            value:
                                '${data.passengers} · ${data.luggageCount} bags')),
                    Expanded(
                        child: _TicketField(
                            label: 'PAYMENT',
                            value: data.paymentMethod == 'cash'
                                ? 'Cash on arrival'
                                : 'Card',
                            alignEnd: true)),
                  ],
                ),
              ],
            ),
          ),

          // ── Total + booking reference ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            color: quiet,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${totalPrice.toStringAsFixed(totalPrice % 1 == 0 ? 0 : 2)} $currency',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'BOOKING REF',
                        style: TextStyle(
                          color: quiet,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        shortId,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeDot() => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.secondary.withValues(alpha: 0.6),
        ),
      );

  Widget _routeLine() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: Colors.white.withValues(alpha: 0.14),
      );
}

class _TicketField extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _TicketField({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The classic ticket fold: side notches + a dotted line between them.
class _TicketPerforation extends StatelessWidget {
  final Color background;

  const _TicketPerforation({required this.background});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dotted line
          Positioned.fill(
            left: 24,
            right: 24,
            child: LayoutBuilder(
              builder: (_, constraints) {
                final dots = (constraints.maxWidth / 12).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < dots; i++)
                      Container(
                        width: 5,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                  ],
                );
              },
            ),
          ),
          // Side notches (cutouts faked with background-colored circles)
          Positioned(
            left: -12,
            top: 0,
            child: _notch(),
          ),
          Positioned(
            right: -12,
            top: 0,
            child: _notch(),
          ),
        ],
      ),
    );
  }

  Widget _notch() => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
      );
}

/// Gold ring whose check stroke draws itself in — calm, no bounce.
class _DrawnCheck extends StatelessWidget {
  final Animation<double> progress;

  const _DrawnCheck({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondary.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.secondary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.22),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: progress,
        builder: (_, __) => CustomPaint(
          painter: _CheckPainter(
            progress: progress.value,
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Check geometry inside the circle
    final p1 = Offset(size.width * 0.30, size.height * 0.52);
    final p2 = Offset(size.width * 0.45, size.height * 0.66);
    final p3 = Offset(size.width * 0.70, size.height * 0.36);

    final seg1 = (p2 - p1).distance;
    final seg2 = (p3 - p2).distance;
    final total = seg1 + seg2;
    final drawn = total * progress;

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (drawn <= seg1) {
      final t = drawn / seg1;
      final mid = Offset.lerp(p1, p2, t)!;
      path.lineTo(mid.dx, mid.dy);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = ((drawn - seg1) / seg2).clamp(0.0, 1.0);
      final end = Offset.lerp(p2, p3, t)!;
      path.lineTo(end.dx, end.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}
