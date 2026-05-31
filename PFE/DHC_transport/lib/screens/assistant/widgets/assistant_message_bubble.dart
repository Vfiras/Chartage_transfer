import 'dart:async';

import 'package:flutter/material.dart';

import '../chat_message_model.dart';
import 'ava_avatar.dart';

const _gold = Color(0xFFC8A96B);
const _bg = Color(0xFF0B0B0D);
const _surface = Color(0xFF1C1C1F);
const _surfaceSecondary = Color(0xFF141416);
const _textColor = Color(0xFFE9E1DA);
const _textSec = Color(0xFFA1A1AA);

class AssistantMessageBubble extends StatefulWidget {
  final ChatMessage message;
  /// Whether to play the typewriter stream. False = render full text instantly.
  final bool animate;
  /// Called periodically while text is streaming so the parent can scroll.
  final VoidCallback? onTextGrew;
  /// Called once when the stream finishes (lets the parent remember it).
  final VoidCallback? onStreamComplete;

  const AssistantMessageBubble({
    super.key,
    required this.message,
    this.animate = false,
    this.onTextGrew,
    this.onStreamComplete,
  });

  @override
  State<AssistantMessageBubble> createState() =>
      _AssistantMessageBubbleState();
}

class _AssistantMessageBubbleState extends State<AssistantMessageBubble>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  // Streaming state
  int _displayedChars = 0;
  Timer? _streamTimer;

  // Keep the bubble alive so scrolling away & back never rebuilds it
  // (which would otherwise replay the stream/fade).
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    if (widget.animate) {
      _startStreaming();
    } else {
      _displayedChars = widget.message.text.length;
    }
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _startStreaming() {
    const interval = Duration(milliseconds: 22);
    _streamTimer = Timer.periodic(interval, (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_displayedChars >= widget.message.text.length) {
        t.cancel();
        widget.onStreamComplete?.call();
        return;
      }
      final step = (_displayedChars % 7 == 0) ? 2 : 1;
      setState(() {
        _displayedChars =
            (_displayedChars + step).clamp(0, widget.message.text.length);
      });
      widget.onTextGrew?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final displayText = widget.message.text.substring(0, _displayedChars);
    final isComplete = _displayedChars >= widget.message.text.length;
    final showCard = widget.message.inlineCard == InlineCard.scheduleUpdate &&
        isComplete;

    return FadeTransition(
      opacity: _fade,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18, right: 32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: AvaAvatar(),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayText,
                          style: const TextStyle(
                            color: _textColor,
                            fontSize: 14,
                            height: 1.55,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (!isComplete) const _BlinkingCursor(),
                      ],
                    ),
                  ),

                  // Inline rich card (Schedule Updated)
                  if (showCard) ...[
                    const SizedBox(height: 8),
                    const _ScheduleUpdateCard(),
                  ],

                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      widget.message.timeLabel,
                      style: const TextStyle(
                        color: _textSec,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inline "Schedule Updated" card ─────────────────────────────────────────────

class _ScheduleUpdateCard extends StatelessWidget {
  const _ScheduleUpdateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SCHEDULE UPDATED',
                style: TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              Icon(Icons.check_circle_rounded, color: _gold, size: 18),
            ],
          ),
          const SizedBox(height: 14),
          const _CardRow(label: 'New Pickup Time', value: '05:10 AM'),
          const _CardRow(
              label: 'Vehicle Amenities', value: 'Sparkling Water added'),
          const SizedBox(height: 16),
          // View Full Details button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text(
              'VIEW FULL DETAILS',
              style: TextStyle(
                color: _bg,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final String label;
  final String value;

  const _CardRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 9),
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: _textSec, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _textColor,
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

// ── Blinking cursor (ChatGPT-style) ────────────────────────────────────────────

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        width: 2,
        height: 14,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: _gold,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
