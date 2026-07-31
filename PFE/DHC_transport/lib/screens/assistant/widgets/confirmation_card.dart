import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ava_card_data.dart';
import 'ava_card_tokens.dart';

/// Ticket-style confirmation card with a gold left-edge accent bar and real
/// Confirm / Cancel buttons. Tapping a button sends "yes"/"no" through the same
/// controller send path a typed message uses. Both buttons disable immediately
/// after a choice (no double-send) and the card marks itself resolved.
class ConfirmationCard extends StatefulWidget {
  final ConfirmationCardData data;

  /// Sends the backing text ("yes"/"no") as a real chat message.
  final void Function(String sendText) onRespond;

  /// Gates taps to the controller's canSend (mirrors the input bar).
  final bool enabled;

  const ConfirmationCard({
    super.key,
    required this.data,
    required this.onRespond,
    this.enabled = true,
  });

  @override
  State<ConfirmationCard> createState() => _ConfirmationCardState();
}

class _ConfirmationCardState extends State<ConfirmationCard> {
  bool _resolved = false;
  String? _choice; // confirmSendText or cancelSendText

  void _respond(String sendText) {
    if (_resolved || !widget.enabled) return;
    HapticFeedback.lightImpact();
    setState(() {
      _resolved = true;
      _choice = sendText;
    });
    widget.onRespond(sendText);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final goldAlpha = _resolved ? 0.30 : 0.85;

    return AvaCardEntrance(
      // ClipRRect rounds the corners so the Positioned left bar follows them.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Card body — Stack sizes to this non-positioned child.
            Container(
              decoration: BoxDecoration(
                color: kAvaSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: kAvaGold.withValues(alpha: _resolved ? 0.10 : 0.18),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment_turned_in_outlined,
                          color: kAvaGold, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'CONFIRMATION',
                        style: TextStyle(
                          color: kAvaGold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    d.actionLabel,
                    style: const TextStyle(
                      color: kAvaOnSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (d.details.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const _PerforatedDivider(),
                    const SizedBox(height: 14),
                    for (var i = 0; i < d.details.length; i++)
                      AvaDetailRowView(
                        label: d.details[i].label,
                        value: d.details[i].value,
                        last: i == d.details.length - 1,
                      ),
                  ],
                  const SizedBox(height: 16),
                  if (_resolved)
                    _ResolvedChip(confirmed: _choice == d.confirmSendText)
                  else
                    _Buttons(
                      data: d,
                      enabled: widget.enabled,
                      onConfirm: () => _respond(d.confirmSendText),
                      onCancel: () => _respond(d.cancelSendText),
                    ),
                ],
              ),
            ),
            // Gold left-edge accent bar — the "this needs you" signal.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: Container(color: kAvaGold.withValues(alpha: goldAlpha)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  final ConfirmationCardData data;
  final bool enabled;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _Buttons({
    required this.data,
    required this.enabled,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final confirm = _PillButton(
          label: data.confirmLabel,
          filled: true,
          enabled: enabled,
          onTap: onConfirm,
        );
        final cancel = _PillButton(
          label: data.cancelLabel,
          filled: false,
          enabled: enabled,
          onTap: onCancel,
        );
        if (c.maxWidth < 240) {
          return Column(
            children: [confirm, const SizedBox(height: 10), cancel],
          );
        }
        return Row(
          children: [
            Expanded(child: confirm),
            const SizedBox(width: 10),
            Expanded(child: cancel),
          ],
        );
      },
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool filled;
  final bool enabled;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.filled,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? kAvaGold : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: filled
                ? null
                : Border.all(color: kAvaGold.withValues(alpha: 0.45)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: filled ? kAvaBg : kAvaGold,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResolvedChip extends StatelessWidget {
  final bool confirmed;
  const _ResolvedChip({required this.confirmed});

  @override
  Widget build(BuildContext context) {
    final color = confirmed ? kAvaGold : kAvaTextSec;
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(confirmed ? Icons.check_rounded : Icons.close_rounded,
              color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            confirmed ? 'Confirmed' : 'Cancelled',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Boarding-pass perforation: a dashed hairline between summary and actions.
class _PerforatedDivider extends StatelessWidget {
  const _PerforatedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashPainter(),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 4.0, gap = 4.0;
    final paint = Paint()
      ..color = kAvaOutline.withValues(alpha: 0.6)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + dash, 0.5), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
