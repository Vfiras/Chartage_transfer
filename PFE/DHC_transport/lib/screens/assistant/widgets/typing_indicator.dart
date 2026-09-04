import 'package:flutter/material.dart';

import '../../../shared/widgets/client/premium_client_components.dart';

import 'ava_avatar.dart';

const _gold = Color(0xFFC8A96B);
Color _surface(BuildContext c) => PremiumClientTheme.elevated(c);

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const AvaAvatar(size: 30),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: _surface(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
              border: Border.all(color: PremiumClientTheme.glassBorder(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0.0, ctrl: _ctrl),
                const SizedBox(width: 5),
                _Dot(delay: 0.22, ctrl: _ctrl),
                const SizedBox(width: 5),
                _Dot(delay: 0.44, ctrl: _ctrl),
                const SizedBox(width: 10),
                // Concierge reassurance: dispatches can take several seconds,
                // and silence reads as a hang. Quiet copy, no gold.
                Text(
                  'AVA is preparing your answer…',
                  style: TextStyle(
                    color: PremiumClientTheme.muted(context),
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
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

class _Dot extends StatelessWidget {
  final double delay;
  final AnimationController ctrl;

  const _Dot({required this.delay, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ((ctrl.value - delay) % 1.0);
        final scale = t > 0.0 && t < 0.5
            ? 1.0 +
                0.45 *
                    Curves.easeInOut.transform(
                        t < 0.25 ? t / 0.25 : (0.5 - t) / 0.25)
            : 1.0;
        final opacity = t > 0 && t < 0.5 ? 1.0 : 0.4;
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
