import 'package:flutter/material.dart';

import '../ava_card_data.dart';
import 'ava_card_tokens.dart';

/// Resolved-action card. Same ticket shape as the confirmation card but muted
/// (no gold accent — the action is over, nothing more is needed). A status icon,
/// a one-line headline, and optional detail rows that collapse when there are
/// more than three.
class ResultCard extends StatefulWidget {
  final ResultCardData data;
  const ResultCard({super.key, required this.data});

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  bool _expanded = false;

  Color get _accent {
    switch (widget.data.status) {
      case AvaResultStatus.success:
        return kAvaSuccess;
      case AvaResultStatus.cancelled:
        return kAvaTextSec;
      case AvaResultStatus.failed:
        return kAvaDanger;
    }
  }

  IconData get _icon {
    switch (widget.data.status) {
      case AvaResultStatus.success:
        return Icons.check_circle_rounded;
      case AvaResultStatus.cancelled:
        return Icons.cancel_rounded;
      case AvaResultStatus.failed:
        return Icons.error_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final details = d.details;
    final collapsible = details.length > 3;
    final shown = collapsible && !_expanded ? details.take(2).toList() : details;

    return AvaCardEntrance(
      child: Container(
        decoration: BoxDecoration(
          color: kAvaSurfaceSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: _accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    d.headline,
                    style: const TextStyle(
                      color: kAvaOnSurface,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (var i = 0; i < shown.length; i++)
                AvaDetailRowView(
                  label: shown[i].label,
                  value: shown[i].value,
                  last: i == shown.length - 1,
                ),
              if (collapsible)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _expanded
                              ? 'Show less'
                              : 'Show ${details.length - 2} more',
                          style: const TextStyle(
                            color: kAvaTextSec,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: kAvaTextSec,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
