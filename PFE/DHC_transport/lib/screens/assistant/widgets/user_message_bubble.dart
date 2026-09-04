import 'package:flutter/material.dart';

import '../../../shared/widgets/client/premium_client_components.dart';

import '../../../core/services/auth_service.dart';
import '../../../widgets/common/fallback_network_image.dart';
import '../chat_message_model.dart';

const _goldBg = Color(0x26C8A96B);   // ~15% gold fill
const _goldBorder = Color(0x33C8A96B); // ~20% gold border
Color _textColor(BuildContext c) => PremiumClientTheme.text(c);

class UserMessageBubble extends StatefulWidget {
  final ChatMessage message;

  /// Space beneath this bubble. The client chat passes 20 between exchange
  /// pairs and 8 within same-sender runs; default preserves other callers.
  final double bottomSpacing;

  const UserMessageBubble({
    super.key,
    required this.message,
    this.bottomSpacing = 18,
  });

  @override
  State<UserMessageBubble> createState() => _UserMessageBubbleState();
}

class _UserMessageBubbleState extends State<UserMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.12, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: EdgeInsets.only(bottom: widget.bottomSpacing, left: 48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: _goldBg,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        border: Border.all(color: _goldBorder, width: 1),
                      ),
                      child: Text(
                        widget.message.text,
                        style: TextStyle(
                          color: _textColor(context),
                          fontSize: 14,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message.timeLabel,
                      // Recedes into a supporting role.
                      style: TextStyle(
                        color: PremiumClientTheme.muted(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _UserChatAvatar(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The client's real profile photo beside their message (fallback: icon).
class _UserChatAvatar extends StatelessWidget {
  const _UserChatAvatar();

  @override
  Widget build(BuildContext context) {
    final avatarUrl = AuthService.instance.currentUser?.avatarUrl;
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _goldBorder),
      ),
      child: ClipOval(
        child: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? FallbackNetworkImage(url: avatarUrl, fit: BoxFit.cover)
            : const ColoredBox(
                color: Color(0xFF141313),
                child: Icon(Icons.person_rounded,
                    color: Color(0xFFC8A96B), size: 16),
              ),
      ),
    );
  }
}
