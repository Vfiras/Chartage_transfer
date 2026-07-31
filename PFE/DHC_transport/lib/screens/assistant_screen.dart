import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/services/auth_service.dart';
import 'assistant/assistant_controller.dart';
import 'assistant/widgets/assistant_message_bubble.dart';
import 'assistant/widgets/ava_avatar.dart';
import 'assistant/widgets/typing_indicator.dart';
import 'assistant/widgets/user_message_bubble.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFF0B0B0D);
const _surfaceElevated = Color(0xFF1C1C1F);
const _gold = Color(0xFFC8A96B);
const _onSurface = Color(0xFFE9E1DA);
const _warmWhite = Color(0xFFF2ECE3);
const _textSec = Color(0xFFA1A1AA);

/// The AVA concierge screen — designed as a first-class lounge, not a
/// support-ticket page.
///
/// Two states, one deliberate transition:
///   LOUNGE       zero messages — the concierge receives you: framed portrait
///                on a soft gold stage light, a quiet greeting, the invitation
///                as the hero line, and prepared conversation starters.
///   CONVERSATION first message onward — the lounge yields entirely; the top
///                bar gains her small portrait and the chat owns the screen.
/// The switch is a 250ms ease-out fade — a state change, not a scroll position.
class AssistantScreen extends StatefulWidget {
  /// Supplied when AVA is hosted as a shell tab rather than a pushed route —
  /// there is nothing to pop, so the back arrow returns to the Home tab.
  final VoidCallback? onBack;

  /// Sent automatically once the screen mounts (used by the Home AVA widget's
  /// voice shortcut, which transcribes first and then opens the chat).
  final String? initialMessage;

  const AssistantScreen({super.key, this.onBack, this.initialMessage});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final AssistantController _ctrl;

  /// "Your concierge has arrived" — played once per app session, not once
  /// per screen open.
  static bool _sessionEntrancePlayed = false;
  late final bool _playEntrance;

  @override
  void initState() {
    super.initState();
    _playEntrance = !_sessionEntrancePlayed;
    _sessionEntrancePlayed = true;
    _ctrl = AssistantController(userFirstName: _firstName)
      ..addListener(_onUpdate);
    final preset = widget.initialMessage?.trim();
    if (preset != null && preset.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(preset));
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _ctrl
      ..removeListener(_onUpdate)
      ..dispose();
    super.dispose();
  }

  void _onUpdate() {
    setState(() {});
    _scheduleScrollToBottom();
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _textCtrl.text).trim();
    if (text.isEmpty || !_ctrl.canSend) return;
    _textCtrl.clear();
    HapticFeedback.lightImpact();
    await _ctrl.sendMessage(text);
  }

  bool get _inConversation => _ctrl.messages.isNotEmpty;

  // ── Greeting ────────────────────────────────────────────────────────────────

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _firstName {
    final name = AuthService.instance.currentUser?.name ?? 'Guest';
    return name.split(' ').first;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── App bar: gains the mini portrait once conversing ─────────────
          _TopBar(compressed: _inConversation, onBack: widget.onBack),

          // ── Lounge ⇄ conversation ────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  child: _inConversation
                      ? _buildConversation(bottomPadding)
                      : _buildLounge(bottomPadding),
                ),

                // ── Fixed input bar ────────────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _InputBar(
                    controller: _textCtrl,
                    enabled: _ctrl.canSend,
                    onSend: () => _send(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Zero messages: the concierge receives you.
  Widget _buildLounge(double bottomPadding) {
    return ListView(
      key: const ValueKey('lounge'),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 110 + bottomPadding),
      children: [
        const SizedBox(height: 22),
        _ConciergeLounge(
          greeting: _greeting,
          firstName: _firstName,
          playEntrance: _playEntrance,
        ),
        const SizedBox(height: 30),
        _SuggestionChips(onAction: _send, enabled: _ctrl.canSend),
        const SizedBox(height: 20),
        // Quiet hint — inviting without begging.
        Text(
          'Ask about your trips, our fleet, or anything else.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12,
            height: 1.4,
          ),
        ),
        // A send is possible from the lounge (typed message) — show the
        // typing dots here too so the transition never feels dead.
        if (_ctrl.isTyping) ...[
          const SizedBox(height: 24),
          const TypingIndicator(),
        ],
      ],
    );
  }

  /// First message onward: the conversation owns the screen.
  Widget _buildConversation(double bottomPadding) {
    final messages = _ctrl.messages;
    return ListView(
      key: const ValueKey('conversation'),
      controller: _scrollCtrl,
      padding: EdgeInsets.fromLTRB(20, 18, 20, 110 + bottomPadding),
      children: [
        for (var i = 0; i < messages.length; i++)
          _bubbleFor(
            messages[i],
            // Rhythm: exchanges breathe (20), same-sender runs group (8).
            bottomSpacing: i == messages.length - 1
                ? 8
                : (messages[i + 1].fromUser == messages[i].fromUser ? 8 : 20),
          ),
        if (_ctrl.isTyping) const TypingIndicator(),
      ],
    );
  }

  Widget _bubbleFor(dynamic msg, {required double bottomSpacing}) {
    if (msg.fromUser) {
      return UserMessageBubble(
        key: ValueKey(msg.id),
        message: msg,
        bottomSpacing: bottomSpacing,
      );
    }
    return AssistantMessageBubble(
      key: ValueKey(msg.id),
      message: msg,
      bottomSpacing: bottomSpacing,
      // Stream only the first time this message appears
      animate: msg.shouldStream && !_ctrl.hasStreamed(msg.id),
      onTextGrew: _scrollToBottom,
      onStreamComplete: () => _ctrl.markStreamed(msg.id),
      // Card button/row taps go through the SAME send path
      // as a typed message; gated by the controller's canSend.
      onCardAction: _send,
      cardEnabled: _ctrl.canSend,
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  /// In conversation the bar carries the concierge presence: her small
  /// portrait joins the wordmark, so the lounge can leave the stage.
  final bool compressed;

  /// Non-null when AVA is a shell tab — pops back to Home instead of the route.
  final VoidCallback? onBack;

  const _TopBar({required this.compressed, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.92),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          _TopBarBtn(
            icon: Icons.arrow_back_rounded,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            child: compressed
                ? Row(
                    key: const ValueKey('bar-compressed'),
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      AvaAvatar(size: 28, borderWidth: 1),
                      SizedBox(width: 9),
                      Text(
                        'AVA',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'AVA',
                    key: ValueKey('bar-wordmark'),
                    style: TextStyle(
                      color: _gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
          ),
          const Spacer(),
          // Balances the back button so the wordmark stays centered.
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _TopBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopBarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _surfaceElevated,
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(icon, color: _onSurface, size: 20),
      ),
    );
  }
}

// ── The concierge lounge ──────────────────────────────────────────────────────

/// Framed portrait on a backlit stage light, greeting as context, the
/// invitation as the hero, credential as a typographic detail.
///
/// Entrance (once per session): 200ms fade + 0.96→1.0 scale, and the gold
/// vignette takes a single quiet breath. Nothing bounces.
class _ConciergeLounge extends StatefulWidget {
  final String greeting;
  final String firstName;
  final bool playEntrance;

  const _ConciergeLounge({
    required this.greeting,
    required this.firstName,
    required this.playEntrance,
  });

  @override
  State<_ConciergeLounge> createState() => _ConciergeLoungeState();
}

class _ConciergeLoungeState extends State<_ConciergeLounge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _vignette;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));

    // Arrival: fade + gentle settle in the first ~200ms.
    final entrance = CurvedAnimation(
        parent: _anim, curve: const Interval(0.0, 0.28, curve: Curves.easeOut));
    _fade = entrance;
    _scale = Tween(begin: 0.96, end: 1.0).animate(entrance);

    // One vignette breath: 8% → 14% → 8%, then still forever.
    _vignette = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.08), weight: 25),
      TweenSequenceItem(
          tween: Tween(begin: 0.08, end: 0.14)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 35),
      TweenSequenceItem(
          tween: Tween(begin: 0.14, end: 0.08)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
    ]).animate(_anim);

    if (widget.playEntrance) {
      _anim.forward();
    } else {
      _anim.value = 1.0; // already arrived this session
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Opacity(
        opacity: _fade.value,
        child: Transform.scale(
          scale: _scale.value,
          child: Column(
            children: [
              // ── Framed portrait on its stage light ──────────────────────
              SizedBox(
                width: 168,
                height: 148,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Backlit stage light — light, not ornament.
                    Container(
                      width: 168,
                      height: 148,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 0.62,
                          colors: [
                            _gold.withValues(alpha: _vignette.value),
                            _gold.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    // Thin gold ring, quiet.
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _gold.withValues(alpha: 0.30), width: 1),
                      ),
                    ),
                    const AvaAvatar(size: 92, borderWidth: 0.8),
                    // LIVE — capsule, gold dot, small.
                    Positioned(
                      bottom: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xF01C1C1F),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: _gold.withValues(alpha: 0.28)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: _gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: _gold.withValues(alpha: 0.95),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Greeting: context, not the moment ───────────────────────
              Text(
                '${widget.greeting}, ${widget.firstName}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _gold.withValues(alpha: 0.90),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 10),

              // ── The hero: the invitation ────────────────────────────────
              const Text(
                'How may I assist you today?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _warmWhite,
                  fontSize: 26,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                  height: 1.25,
                ),
              ),

              const SizedBox(height: 20),

              // ── Credential as typography, not a badge ───────────────────
              Container(
                width: 34,
                height: 1,
                color: _gold.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 10),
              Text(
                'SENIOR TRAVEL CONCIERGE · AVAILABLE 24/7',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _gold.withValues(alpha: 0.80),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Suggestion chips — prepared conversation starters ─────────────────────────

/// Not a menu of features: a row of first messages, written the way a person
/// would say them. Tapping one sends exactly what it says.
class _SuggestionChips extends StatelessWidget {
  final void Function(String) onAction;
  final bool enabled;

  const _SuggestionChips({required this.onAction, required this.enabled});

  static const _suggestions = <(IconData, String)>[
    (Icons.edit_calendar_outlined, 'Change my upcoming trip'),
    (Icons.near_me_outlined, "Where's my driver?"),
    (Icons.flight_land_outlined, 'Airport meet-and-greet'),
    (Icons.star_outline_rounded, 'My rewards & benefits'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (icon, label) = _suggestions[i];
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1 : 0.5,
            child: GestureDetector(
              onTap: enabled ? () => onAction(label) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _surfaceElevated.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.07)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: _gold, size: 15),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: _onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Input bar ──────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _speech = SpeechToText();
  final _focus = FocusNode();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  Future<void> _toggleListen() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize(onError: (_) {
      if (mounted) setState(() => _isListening = false);
    });
    if (!available || !mounted) return;
    setState(() => _isListening = true);
    HapticFeedback.mediumImpact();
    await _speech.listen(
      onResult: (result) {
        widget.controller.text = result.recognizedWords;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      },
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
    if (mounted) setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _speech.stop();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The field acknowledges attention: gold 20% at rest, 60% in focus.
    final borderAlpha = _focus.hasFocus ? 0.60 : 0.20;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 10, 16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        children: [
          // ── Mic button ─────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.enabled ? _toggleListen : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isListening
                    ? _gold.withValues(alpha: 0.20)
                    : _surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isListening
                      ? _gold.withValues(alpha: 0.60)
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening ? _gold : _textSec,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── Input pill ─────────────────────────────────────────────────
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _surfaceElevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: _gold.withValues(alpha: borderAlpha)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined,
                      color: _gold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      cursorColor: _gold,
                      style: const TextStyle(
                          color: _onSurface, fontSize: 14),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        hintText: _isListening
                            ? 'Listening...'
                            : 'Message AVA...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF6B6460), fontSize: 14),
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => widget.onSend(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── Send button ────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.enabled ? widget.onSend : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.enabled ? _gold : _surfaceElevated,
                shape: BoxShape.circle,
                border: widget.enabled
                    ? null
                    : Border.all(color: _gold.withValues(alpha: 0.22)),
                boxShadow: widget.enabled
                    ? [
                        BoxShadow(
                          color: _gold.withValues(alpha: 0.32),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.send_rounded,
                color: widget.enabled ? _bg : _textSec,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
