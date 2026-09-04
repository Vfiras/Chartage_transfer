import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/services/auth_service.dart';
import '../core/services/language_service.dart';
import '../shared/widgets/client/premium_client_components.dart';
import 'assistant/assistant_controller.dart';
import 'assistant/chat_message_model.dart';
import 'assistant/widgets/assistant_message_bubble.dart';
import 'assistant/widgets/booking_form_card.dart';
import 'assistant/widgets/cancel_booking_card.dart';
import 'assistant/widgets/modify_booking_card.dart';
import 'assistant/widgets/ava_avatar.dart';
import 'assistant/widgets/typing_indicator.dart';
import 'assistant/widgets/user_message_bubble.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
// Gold is the one constant across themes; every other surface resolves per
// brightness so the lounge is not a dark island inside a light app.
const _gold = Color(0xFFC8A96B);

Color _bg(BuildContext c) => PremiumClientTheme.background(c);
Color _surfaceElevated(BuildContext c) => PremiumClientTheme.elevated(c);
Color _onSurface(BuildContext c) => PremiumClientTheme.text(c);
Color _textSec(BuildContext c) => PremiumClientTheme.muted(c);
Color _hairline(BuildContext c) => PremiumClientTheme.glassBorder(c);

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
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    // Clear the input bar exactly: its own height plus the gesture inset it
    // sits on. A fixed guess left the last reply hidden behind the bar on
    // devices with a tall home indicator.
    final listBottomInset =
        _kInputBarHeight + MediaQuery.of(context).padding.bottom + 24 + keyboard;

    return Scaffold(
      backgroundColor: _bg(context),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── App bar: gains the mini portrait once conversing ─────────────
          _TopBar(compressed: _inConversation, onBack: widget.onBack),

          // ── Persistent quick actions ──────────────────────────────────────
          // Once conversing the lounge is gone, but its starters stay reachable
          // as a compact rail so a second request never needs typing.
          if (_inConversation)
            _SuggestionChips(
              onAction: _send,
              enabled: _ctrl.canSend,
              compact: true,
            ),

          // ── Lounge ⇄ conversation ────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeOut,
                  child: _inConversation
                      ? _buildConversation(listBottomInset)
                      : _buildLounge(listBottomInset),
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
  Widget _buildLounge(double bottomInset) {
    return ListView(
      key: const ValueKey('lounge'),
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset),
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
          LanguageService.instance.t('ava_lounge_hint'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textSec(context).withValues(alpha: 0.75),
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
  Widget _buildConversation(double bottomInset) {
    final messages = _ctrl.messages;
    return ListView(
      key: const ValueKey('conversation'),
      controller: _scrollCtrl,
      padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset),
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

  /// A card's submission bypasses intent detection — otherwise the sentence
  /// it produces ("Please book a trip from ...") would match the booking
  /// detector again and open a second form instead of reaching AVA.
  Future<void> _submitFromCard(String message) async {
    if (!_ctrl.canSend) return;
    HapticFeedback.lightImpact();
    await _ctrl.sendMessage(message, allowIntentCards: false);
  }

  Widget _interactiveCardFor(ChatMessage msg) {
    final seed = msg.cardSeed ?? const {};
    switch (msg.interactiveCard) {
      case AvaInteractiveCard.bookingForm:
        return BookingFormCard(
          key: ValueKey(msg.id),
          initialPickup: seed['pickup'] as String?,
          initialDestination: seed['destination'] as String?,
          onSubmit: _submitFromCard,
        );
      case AvaInteractiveCard.modifyBooking:
        return ModifyBookingCard(
          key: ValueKey(msg.id),
          bookings: _bookingsFrom(seed),
          onSubmit: _submitFromCard,
        );
      case AvaInteractiveCard.cancelBooking:
        return CancelBookingCard(
          key: ValueKey(msg.id),
          bookings: _bookingsFrom(seed),
          onSubmit: _submitFromCard,
        );
      case AvaInteractiveCard.none:
        return const SizedBox.shrink();
    }
  }

  static List<Map<String, dynamic>> _bookingsFrom(Map<String, dynamic> seed) =>
      ((seed['bookings'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

  Widget _bubbleFor(dynamic msg, {required double bottomSpacing}) {
    if (msg is ChatMessage && msg.isInteractive) {
      return _interactiveCardFor(msg);
    }
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
        color: _bg(context).withValues(alpha: 0.92),
        border: Border(bottom: BorderSide(color: _hairline(context))),
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
          color: _surfaceElevated(context),
          border: Border.all(color: _hairline(context)),
        ),
        child: Icon(icon, color: _onSurface(context), size: 20),
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
                          color: _surfaceElevated(context),
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
              Text(
                LanguageService.instance.t('ava_lounge_hero'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _onSurface(context),
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

  /// Conversation mode: a slimmer rail pinned under the app bar, so the
  /// starters stay one tap away without competing with the messages.
  final bool compact;

  const _SuggestionChips({
    required this.onAction,
    required this.enabled,
    this.compact = false,
  });

  /// Label key -> the message actually sent. The sent text is deliberately
  /// NOT translated: the backend's intent routing matches English phrasing.
  static const _suggestions = <(IconData, String, String)>[
    (Icons.edit_calendar_outlined, 'ava_sg_change_trip',
        'Change my upcoming trip'),
    (Icons.near_me_outlined, 'ava_sg_driver', "Where's my driver?"),
    (Icons.flight_land_outlined, 'ava_sg_meet_greet',
        'Airport meet-and-greet'),
    (Icons.star_outline_rounded, 'ava_sg_rewards', 'My rewards & benefits'),
  ];

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final height = compact ? 34.0 : 42.0;

    final rail = SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 20)
            : EdgeInsets.zero,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => SizedBox(width: compact ? 8 : 10),
        itemBuilder: (context, i) {
          final (icon, key, prompt) = _suggestions[i];
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1 : 0.5,
            child: GestureDetector(
              onTap: enabled ? () => onAction(prompt) : null,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _surfaceElevated(context).withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _hairline(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: _gold, size: compact ? 13 : 15),
                    SizedBox(width: compact ? 6 : 8),
                    Text(
                      l.t(key),
                      style: TextStyle(
                        color: _onSurface(context),
                        fontSize: compact ? 11 : 13,
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

    if (!compact) return rail;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: rail,
    );
  }
}

// ── Input bar ──────────────────────────────────────────────────────────────────

/// Vertical space the bar occupies above the device's bottom inset:
/// 10 top padding + 48 control + 10 bottom padding.
const double _kInputBarHeight = 68;

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

  void _unavailable() {
    if (!mounted) return;
    setState(() => _isListening = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LanguageService.instance.t('ava_voice_unavailable')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Press to dictate, press again to send.
  ///
  /// initialize() throws rather than returning false when the platform has no
  /// recogniser or the permission is refused (an emulator with no mic is the
  /// common case), so the whole flow is guarded — a failed dictation must
  /// never take the chat down with it.
  Future<void> _toggleListen() async {
    if (_isListening) {
      await _stopAndSend();
      return;
    }
    try {
      final available = await _speech.initialize(
        onError: (_) => _unavailable(),
        onStatus: (status) {
          // The recogniser stops itself after pauseFor; reflect that in the
          // icon instead of leaving it stuck in the listening state.
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) setState(() => _isListening = false);
          }
        },
      );
      if (!available) {
        _unavailable();
        return;
      }
      if (!mounted) return;
      setState(() => _isListening = true);
      HapticFeedback.mediumImpact();
      await _speech.listen(
        onResult: (result) {
          widget.controller.text = result.recognizedWords;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: widget.controller.text.length),
          );
          if (mounted) setState(() {});
        },
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      _unavailable();
    }
  }

  Future<void> _stopAndSend() async {
    try {
      await _speech.stop();
    } catch (_) {
      // Already stopped — nothing to recover from.
    }
    if (!mounted) return;
    setState(() => _isListening = false);
    // Dictation ends with a send: the point of talking is not to fill a box.
    if (widget.controller.text.trim().isNotEmpty) {
      widget.onSend();
    }
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

    final l = LanguageService.instance;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 10, 16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: _bg(context),
        border: Border(top: BorderSide(color: _hairline(context))),
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
                    : _surfaceElevated(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isListening
                      ? _gold.withValues(alpha: 0.60)
                      : _hairline(context),
                ),
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening ? _gold : _textSec(context),
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
                color: _surfaceElevated(context),
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
                      style: TextStyle(
                          color: _onSurface(context), fontSize: 14),
                      // The app theme sets filled + enabled/focused
                      // OutlineInputBorders. `border:` alone is only the
                      // fallback, so those kept painting a second rounded
                      // outline INSIDE this pill — the double ring. Every
                      // state has to be cleared explicitly.
                      decoration: InputDecoration(
                        isCollapsed: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: _isListening
                            ? l.t('ava_listening')
                            : l.t('ava_input_hint'),
                        hintStyle: TextStyle(
                            color: _textSec(context), fontSize: 14),
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
                color: widget.enabled ? _gold : _surfaceElevated(context),
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
                color: widget.enabled
                    ? const Color(0xFF141313)
                    : _textSec(context),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
