import 'package:flutter/material.dart';

/// Design tokens mirrored from assistant_screen.dart / assistant_message_bubble
/// so the cards are pixel-native to the existing chat, not a bolted-on palette.
const kAvaBg = Color(0xFF0B0B0D);
const kAvaSurface = Color(0xFF1C1C1F);
const kAvaSurfaceSecondary = Color(0xFF141416);
const kAvaGold = Color(0xFFC8A96B);
const kAvaOnSurface = Color(0xFFE9E1DA);
const kAvaTextSec = Color(0xFFA1A1AA);
const kAvaOutline = Color(0xFF4D463A);
const kAvaSuccess = Color(0xFF22C55E);
const kAvaDanger = Color(0xFFE07070);
const kAvaHairline = Color(0x0FFFFFFF); // white @ ~6%

/// One deliberate motion moment: a card "stamps in" with a brief scale-up + fade
/// (≈140ms). Honors the OS reduced-motion accessibility flag (no new app flag).
class AvaCardEntrance extends StatefulWidget {
  final Widget child;
  const AvaCardEntrance({super.key, required this.child});

  @override
  State<AvaCardEntrance> createState() => _AvaCardEntranceState();
}

class _AvaCardEntranceState extends State<AvaCardEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.96, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.topCenter,
        child: widget.child,
      ),
    );
  }
}

/// Label/value line — matches the existing _CardRow style in the schedule card.
class AvaDetailRowView extends StatelessWidget {
  final String label;
  final String value;
  final bool last;
  const AvaDetailRowView({
    super.key,
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: last ? 0 : 9),
      margin: EdgeInsets.only(bottom: last ? 0 : 9),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: kAvaHairline)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kAvaTextSec, fontSize: 13)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: kAvaOnSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders `**bold**` runs in an info answer as real bold spans, keeping the
/// rest in the base bubble style. Used by the info enhancement.
List<InlineSpan> avaBoldSpans(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final parts = text.split('**');
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) continue;
    final isBold = i.isOdd; // text between ** pairs
    spans.add(TextSpan(
      text: parts[i],
      style: isBold
          ? base.copyWith(color: kAvaOnSurface, fontWeight: FontWeight.w700)
          : base,
    ));
  }
  return spans;
}
