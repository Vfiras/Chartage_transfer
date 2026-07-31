import 'dart:async';

import 'package:flutter/material.dart';

import '../ava_card_data.dart';
import '../chat_message_model.dart';
import 'ava_avatar.dart';
import 'ava_card_tokens.dart';
import 'confirmation_card.dart';
import 'result_card.dart';
import 'selection_card.dart';

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

  /// Sends text through the SAME path a typed message uses, when a card button
  /// or row is tapped. Null disables card interaction.
  final void Function(String text)? onCardAction;

  /// Mirrors the controller's canSend — gates card taps while a send is busy.
  final bool cardEnabled;

  /// Space beneath this bubble. The client chat passes 20 between exchange
  /// pairs and 8 within same-sender runs; default preserves other callers.
  final double bottomSpacing;

  const AssistantMessageBubble({
    super.key,
    required this.message,
    this.animate = false,
    this.onTextGrew,
    this.onStreamComplete,
    this.onCardAction,
    this.cardEnabled = true,
    this.bottomSpacing = 18,
  });

  @override
  State<AssistantMessageBubble> createState() => _AssistantMessageBubbleState();
}

class _AssistantMessageBubbleState extends State<AssistantMessageBubble>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  // Streaming state
  int _displayedChars = 0;
  Timer? _streamTimer;

  @override
  bool get wantKeepAlive => true;

  // ── Card classification ────────────────────────────────────────────────────
  bool get _isStructuredCard {
    final t = widget.message.cardType;
    return t == AvaCardType.confirmation ||
        t == AvaCardType.selection ||
        t == AvaCardType.result;
  }

  /// Strip ** markers from the streaming source so they never flash on screen
  /// for any text-bubble message. Once streaming is complete, the build method
  /// re-renders with avaBoldSpans to produce real bold spans.
  String get _streamSource => _isStructuredCard
      ? widget.message.text
      : widget.message.text.replaceAll('**', '');

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // Structured cards never typewriter — their own entrance handles the appear.
    if (widget.animate && !_isStructuredCard) {
      _startStreaming();
    } else {
      _displayedChars = _streamSource.length;
      if (widget.animate) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => widget.onStreamComplete?.call());
      }
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
      if (_displayedChars >= _streamSource.length) {
        t.cancel();
        widget.onStreamComplete?.call();
        return;
      }
      final step = (_displayedChars % 7 == 0) ? 2 : 1;
      setState(() {
        _displayedChars =
            (_displayedChars + step).clamp(0, _streamSource.length);
      });
      widget.onTextGrew?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final isError = widget.message.isError;

    // ── Structured card: render in place of the text bubble ────────────────
    if (_isStructuredCard) {
      return _frame(
        child: SizedBox(width: double.infinity, child: _buildCard()),
      );
    }

    // ── Text bubble (plain, info-bold, or error) ───────────────────────────
    final displayText = _streamSource.substring(0, _displayedChars);
    final isComplete = _displayedChars >= _streamSource.length;
    final showScheduleCard =
        widget.message.inlineCard == InlineCard.scheduleUpdate && isComplete;

    final bubbleBg = isError ? const Color(0xFF1E0A0A) : _surface;
    final bubbleBorder = isError
        ? const Color(0xFFE53935).withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.06);
    final textStyle = TextStyle(
      color: isError ? const Color(0xFFE07070) : _textColor,
      fontSize: 14,
      height: 1.55,
      fontWeight: FontWeight.w400,
    );

    return _frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Concierge voice: AVA's answers carry a slim gold accent along
          // their left edge (kept OUTSIDE the rounded bubble — a rounded
          // border with one gold side is a Flutter paint assertion).
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isError)
                  Container(
                    width: 2.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (!isError) const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: bubbleBg,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      border: Border.all(color: bubbleBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isError) _errorHeader(),
                        if (!isError && isComplete)
                          RichText(
                            text: TextSpan(
                              children: avaBoldSpans(
                                  widget.message.text, textStyle),
                            ),
                          )
                        else
                          Text(displayText, style: textStyle),
                        if (!isComplete && !isError) const _BlinkingCursor(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showScheduleCard) ...[
            const SizedBox(height: 8),
            const _ScheduleUpdateCard(),
          ],
        ],
      ),
    );
  }

  /// Avatar + content + timestamp frame shared by text bubbles and cards.
  Widget _frame({required Widget child}) {
    return FadeTransition(
      opacity: _fade,
      child: Padding(
        padding: EdgeInsets.only(bottom: widget.bottomSpacing, right: 32),
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
                  child,
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      widget.message.timeLabel,
                      // Recedes into a supporting role.
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.40),
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

  Widget _errorHeader() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE07070), size: 14),
            const SizedBox(width: 5),
            Text(
              'AVA encountered an issue',
              style: TextStyle(
                color: const Color(0xFFE07070).withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );

  /// Returns the right card widget; degrades to plain text if the payload type
  /// somehow doesn't match (defensive — the parser keeps them in sync).
  Widget _buildCard() {
    final m = widget.message;
    final d = m.cardData;
    if (m.cardType == AvaCardType.confirmation && d is ConfirmationCardData) {
      return ConfirmationCard(
        data: d,
        enabled: widget.cardEnabled,
        onRespond: (t) => widget.onCardAction?.call(t),
      );
    }
    if (m.cardType == AvaCardType.selection && d is SelectionCardData) {
      return SelectionCard(
        data: d,
        enabled: widget.cardEnabled,
        onSelect: (t) => widget.onCardAction?.call(t),
      );
    }
    if (m.cardType == AvaCardType.result && d is ResultCardData) {
      return ResultCard(data: d);
    }
    return Text(
      m.text,
      style: const TextStyle(color: _textColor, fontSize: 14, height: 1.55),
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
