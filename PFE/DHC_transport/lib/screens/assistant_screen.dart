import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/services/auth_service.dart';
import 'assistant/assistant_controller.dart';
import 'assistant/widgets/assistant_message_bubble.dart';
import 'assistant/widgets/ava_avatar.dart';
import 'assistant/widgets/typing_indicator.dart';
import 'assistant/widgets/user_message_bubble.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _bg = Color(0xFF0B0B0D);
const _surfaceElevated = Color(0xFF1C1C1F);
const _surfaceSecondary = Color(0xFF141416);
const _gold = Color(0xFFC8A96B);
const _onSurface = Color(0xFFE9E1DA);
const _textSec = Color(0xFFA1A1AA);
const _outline = Color(0xFF4D463A);

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final AssistantController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AssistantController(userFirstName: _firstName)
      ..addListener(_onUpdate);
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
          // ── App bar ──────────────────────────────────────────────────────
          _TopBar(),

          // ── Scrollable content + chat ────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                ListView(
                  controller: _scrollCtrl,
                  padding: EdgeInsets.fromLTRB(
                      20, 8, 20, 100 + bottomPadding),
                  children: [
                    // ── Hero ───────────────────────────────────────────────
                    _HeroSection(greeting: _greeting, firstName: _firstName),
                    const SizedBox(height: 32),

                    // ── Journey card ───────────────────────────────────────
                    _SectionTitle('Upcoming Journey'),
                    const SizedBox(height: 14),
                    const _JourneyCard(),
                    const SizedBox(height: 32),

                    // ── Quick actions ──────────────────────────────────────
                    _SectionTitle('Quick Actions', actionLabel: 'View All'),
                    const SizedBox(height: 14),
                    _QuickActionsGrid(onAction: _send),
                    const SizedBox(height: 32),

                    // ── Chat section ───────────────────────────────────────
                    _SectionTitle('Command Center Chat'),
                    const SizedBox(height: 16),

                    // Messages
                    for (final msg in _ctrl.messages)
                      if (msg.fromUser)
                        UserMessageBubble(key: ValueKey(msg.id), message: msg)
                      else
                        AssistantMessageBubble(
                          key: ValueKey(msg.id),
                          message: msg,
                          // Stream only the first time this message appears
                          animate: msg.shouldStream &&
                              !_ctrl.hasStreamed(msg.id),
                          onTextGrew: _scrollToBottom,
                          onStreamComplete: () => _ctrl.markStreamed(msg.id),
                        ),

                    if (_ctrl.isTyping) const TypingIndicator(),
                  ],
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
}

// ── Top bar ────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
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
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          const Text(
            'LUMIÈRE',
            style: TextStyle(
              color: _gold,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          _TopBarBtn(
            icon: Icons.notifications_none_rounded,
            onTap: () {},
          ),
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

// ── Hero section ───────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final String greeting;
  final String firstName;

  const _HeroSection({required this.greeting, required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Avatar with LIVE badge
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const AvaAvatar(size: 108, borderWidth: 2),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _gold.withValues(alpha: 0.30), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        Text(
          '$greeting, $firstName',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _onSurface,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your personal travel concierge, AVA, is here to assist.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSec, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _gold.withValues(alpha: 0.20)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, color: _gold, size: 15),
              SizedBox(width: 6),
              Text(
                'Senior Travel Concierge',
                style: TextStyle(
                  color: _gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section title ──────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;

  const _SectionTitle(this.title, {this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (actionLabel != null)
          Text(
            actionLabel!,
            style: const TextStyle(
              color: _gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
      ],
    );
  }
}

// ── Journey card (boarding pass style) ────────────────────────────────────────

class _JourneyCard extends StatelessWidget {
  const _JourneyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: 0.12)),
      ),
      child: Stack(
        children: [
          // Gold top accent
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  _gold.withValues(alpha: 0.80),
                  Colors.transparent,
                ]),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status + reference
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: _gold.withValues(alpha: 0.30)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                                color: _gold, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'CONFIRMED',
                            style: TextStyle(
                              color: _gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Ref: CT-2024-89A',
                      style: TextStyle(
                          color: _textSec,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Route row: TUN ──✈── HMT
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AirportCode(code: 'TUN', city: 'Tunis-Carthage'),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children: [
                            // Dashed line with rotated plane sitting on it
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                const Positioned.fill(
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 4),
                                    child: CustomPaint(
                                        painter: _DashedLinePainter()),
                                  ),
                                ),
                                Container(
                                  color: _surfaceElevated,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Transform.rotate(
                                    angle: math.pi / 2,
                                    child: const Icon(Icons.flight,
                                        color: _gold, size: 26),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Text(
                                '1H 15M EST.',
                                style: TextStyle(
                                  color: _gold,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _AirportCode(
                        code: 'HMT',
                        city: 'Hammamet',
                        align: CrossAxisAlignment.end),
                  ],
                ),

                const SizedBox(height: 20),
                Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05)),
                const SizedBox(height: 18),

                // Date / time
                const Row(
                  children: [
                    Expanded(
                      child: _DateTimeInfo(
                          label: 'DATE', value: 'May 29, 2024'),
                    ),
                    Expanded(
                      child:
                          _DateTimeInfo(label: 'TIME', value: '05:25 AM'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Vehicle
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surfaceSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 38,
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: const Icon(Icons.directions_car_rounded,
                            color: _gold, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mercedes S-Class',
                            style: TextStyle(
                              color: _onSurface,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'PREMIUM FLEET',
                            style: TextStyle(
                              color: _gold,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right_rounded,
                          color: _textSec, size: 20),
                    ],
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

class _AirportCode extends StatelessWidget {
  final String code;
  final String city;
  final CrossAxisAlignment align;

  const _AirportCode({
    required this.code,
    required this.city,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          code,
          style: const TextStyle(
            color: _onSurface,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        Text(
          city,
          style: const TextStyle(
              color: _textSec, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _DateTimeInfo extends StatelessWidget {
  final String label;
  final String value;

  const _DateTimeInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _textSec,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: _onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Quick actions grid ─────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final void Function(String) onAction;

  const _QuickActionsGrid({required this.onAction});

  static const _actions = [
    (Icons.edit_calendar_rounded, 'Modify\nBooking', 'Can I modify my booking?'),
    (Icons.luggage_rounded, 'Airport\nAssist', 'Tell me about airport assistance'),
    (Icons.my_location_rounded, 'Track\nRide', 'How do I track my ride?'),
    (Icons.directions_car_rounded, 'Fleet\nInfo', 'What vehicles are available?'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final (icon, label, prompt) in _actions)
          _ActionCard(
            icon: icon,
            label: label,
            onTap: () => onAction(prompt),
          ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _surfaceSecondary,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Icon(icon, color: _gold, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashed line painter (boarding-pass flight route) ──────────────────────────

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = _outline.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => false;
}

// ── Input bar ──────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 10, 16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(
            top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        children: [
          // ── Single input pill ──────────────────────────────────────────
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _surfaceElevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined,
                      color: _gold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: enabled,
                      cursorColor: _gold,
                      style: const TextStyle(
                          color: _onSurface, fontSize: 14),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        hintText: 'Message AVA...',
                        hintStyle:
                            TextStyle(color: Color(0xFF6B6460), fontSize: 14),
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── Send button (no glow) ──────────────────────────────────────
          GestureDetector(
            onTap: enabled ? onSend : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: enabled ? _gold : _gold.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: enabled
                    ? const Color(0xFF0B0B0D)
                    : const Color(0xFF5A5040),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
