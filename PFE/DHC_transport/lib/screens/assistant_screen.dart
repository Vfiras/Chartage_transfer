import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/assistant_service.dart';
import '../shared/widgets/common/luxury_components.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
        text:
            'Good evening. I can help with airport pickup, luggage, pricing, round trips, and vehicle recommendations.',
        fromUser: false),
  ];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send([String? prompt]) async {
    final text = (prompt ?? _controller.text).trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _controller.clear();
      _loading = true;
    });
    try {
      final reply = await const AssistantService().sendMessage(text);
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(text: reply, fromUser: false)));
    } catch (error) {
      if (!mounted) return;
      setState(() =>
          _messages.add(_ChatMessage(text: error.toString(), fromUser: false)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
              child: LuxuryHeader(
                title: 'AI Assistant',
                subtitle: 'Concierge help',
                leading: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.secondary),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: [
                  _PromptChip(
                      label: 'Airport pickup',
                      onTap: () => _send('How does airport pickup work?')),
                  _PromptChip(
                      label: 'Luggage',
                      onTap: () => _send('Which vehicle is best for luggage?')),
                  _PromptChip(
                      label: 'Pricing',
                      onTap: () => _send('How are prices calculated?')),
                  _PromptChip(
                      label: 'Vehicle help',
                      onTap: () => _send('Recommend a vehicle for my group.')),
                  _PromptChip(
                      label: 'Round trip',
                      onTap: () => _send('Can I book a round trip?')),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                itemCount: _messages.length,
                itemBuilder: (context, index) =>
                    _Bubble(message: _messages[index]),
              ),
            ),
            if (_loading)
              const LinearProgressIndicator(
                  minHeight: 2, color: AppColors.secondary),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: LuxuryCard(
                  padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
                  radius: 18,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700),
                          decoration: const InputDecoration(
                            hintText: 'Ask about your trip...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: _loading ? null : () => _send(),
                        icon: const Icon(Icons.send_rounded),
                        style: IconButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        label: Text(label),
        labelStyle: const TextStyle(
            color: AppColors.secondary, fontWeight: FontWeight.w800),
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.goldBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool fromUser;

  const _ChatMessage({required this.text, required this.fromUser});
}

class _Bubble extends StatelessWidget {
  final _ChatMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 330),
        decoration: BoxDecoration(
          color: message.fromUser ? AppColors.secondary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.fromUser ? 18 : 4),
            bottomRight: Radius.circular(message.fromUser ? 4 : 18),
          ),
          border: Border.all(
              color: message.fromUser ? AppColors.secondary : AppColors.border),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: message.fromUser ? AppColors.primary : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
