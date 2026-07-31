import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'assistant_controller.dart';
import 'widgets/analytics_card.dart';
import 'widgets/assistant_message_bubble.dart';
import 'widgets/ava_avatar.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/user_message_bubble.dart';

// Same local design tokens as the client assistant screen + the cards, so the
// reused bubbles/cards render natively here.
const _bg = Color(0xFF0B0B0D);
const _surfaceElevated = Color(0xFF1C1C1F);
const _gold = Color(0xFFC8A96B);
const _onSurface = Color(0xFFE9E1DA);
const _textSec = Color(0xFFA1A1AA);

/// Admin-side AVA chat. Architecturally identical to the client AssistantScreen:
/// it reuses AssistantController (which sends the CURRENT user's JWT, so an admin
/// login reaches the Operations/Insights agents via the backend role gate), the
/// SSE streaming in AssistantApiService, and the same message bubbles + cards.
/// Only the chrome (admin context, admin quick-actions) differs.
class AdminAssistantScreen extends StatefulWidget {
  /// Optional prompt sent automatically once the screen mounts. Null in normal
  /// use (the admin Profile entry constructs `const AdminAssistantScreen()`);
  /// used to deep-link a prompt / drive an automated screenshot.
  final String? autoSend;

  const AdminAssistantScreen({super.key, this.autoSend});

  @override
  State<AdminAssistantScreen> createState() => _AdminAssistantScreenState();
}

class _AdminAssistantScreenState extends State<AdminAssistantScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final AssistantController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AssistantController()..addListener(_onUpdate);
    final auto = widget.autoSend;
    if (auto != null && auto.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(auto));
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          const _TopBar(),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  controller: _scrollCtrl,
                  padding:
                      EdgeInsets.fromLTRB(20, 12, 20, 100 + bottomPadding),
                  children: [
                    const _Header(),
                    const SizedBox(height: 20),
                    _QuickActions(onAction: _send),
                    const SizedBox(height: 24),
                    for (final msg in _ctrl.messages)
                      if (msg.fromUser)
                        UserMessageBubble(key: ValueKey(msg.id), message: msg)
                      else if (msg.isAnalytics)
                        // Business-analysis response → rich KPI/chart card
                        AnalyticsCard(key: ValueKey(msg.id), message: msg)
                      else
                        AssistantMessageBubble(
                          key: ValueKey(msg.id),
                          message: msg,
                          animate: msg.shouldStream &&
                              !_ctrl.hasStreamed(msg.id),
                          onTextGrew: _scrollToBottom,
                          onStreamComplete: () => _ctrl.markStreamed(msg.id),
                          // Card taps go through the same send path as the client.
                          onCardAction: _send,
                          cardEnabled: _ctrl.canSend,
                        ),
                    if (_ctrl.isTyping) const TypingIndicator(),
                  ],
                ),
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

// ── Top bar ─────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 12,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.92),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_back_rounded,
                  color: _onSurface, size: 22),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'AVA',
            style: TextStyle(
              color: _gold,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _gold.withValues(alpha: 0.30)),
            ),
            child: const Text(
              'OPERATIONS',
              style: TextStyle(
                color: _gold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const AvaAvatar(size: 56, borderWidth: 2),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Operations Console',
                    style: TextStyle(
                      color: _onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Ask AVA to manage fleet, pricing and bookings, or pull live insights.',
                    style: TextStyle(color: _textSec, fontSize: 13, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final void Function(String) onAction;
  const _QuickActions({required this.onAction});

  /// BI-focused prompts. The first four hit the `run_business_analysis`
  /// pipeline (chart + KPI payload); the last two are read-only list queries.
  /// The prompt text must keep the phrasing the supervisor's Guard 0 detects,
  /// so these are sent verbatim rather than translated.
  static const _actions = [
    (Icons.insights_rounded, 'Business review', 'Give me a full business review'),
    (Icons.pie_chart_rounded, 'Revenue split',
        'Revenue by vehicle category'),
    (Icons.price_change_rounded, 'Pricing impact',
        'How did our pricing changes affect bookings?'),
    (Icons.calendar_month_rounded, 'Seasonal trends',
        'Show seasonal booking trends'),
    (Icons.pending_actions_rounded, 'Pending',
        'List all pending bookings'),
    (Icons.feedback_rounded, 'Complaints', 'Show me open complaints'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (icon, label, prompt) in _actions)
          GestureDetector(
            onTap: () => onAction(prompt),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: _gold, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: _onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
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
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _surfaceElevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
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
                      style:
                          const TextStyle(color: _onSurface, fontSize: 14),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        hintText: 'Message AVA…',
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
