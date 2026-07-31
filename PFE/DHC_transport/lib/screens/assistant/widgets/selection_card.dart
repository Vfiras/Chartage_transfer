import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ava_card_data.dart';
import 'ava_card_tokens.dart';

/// Disambiguation card: a vertical stack of tappable route rows. Tapping a row
/// sends that option's exact backing text (the ordinal, e.g. "1") through the
/// normal controller send path, and highlights the chosen row. After one pick
/// the list locks (no double-send).
class SelectionCard extends StatefulWidget {
  final SelectionCardData data;
  final void Function(String sendText) onSelect;
  final bool enabled;

  const SelectionCard({
    super.key,
    required this.data,
    required this.onSelect,
    this.enabled = true,
  });

  @override
  State<SelectionCard> createState() => _SelectionCardState();
}

class _SelectionCardState extends State<SelectionCard> {
  int? _picked;

  void _pick(int index, String sendText) {
    if (_picked != null || !widget.enabled) return;
    HapticFeedback.selectionClick();
    setState(() => _picked = index);
    widget.onSelect(sendText);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return AvaCardEntrance(
      child: Container(
        decoration: BoxDecoration(
          color: kAvaSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kAvaGold.withValues(alpha: 0.16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.alt_route_rounded, color: kAvaGold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d.prompt,
                      style: const TextStyle(
                        color: kAvaOnSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < d.options.length; i++)
              _OptionRow(
                option: d.options[i],
                index: i,
                selected: _picked == i,
                dimmed: _picked != null && _picked != i,
                showTopBorder: i != 0,
                enabled: widget.enabled && _picked == null,
                onTap: () => _pick(i, d.options[i].sendText),
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final AvaSelectionOption option;
  final int index;
  final bool selected;
  final bool dimmed;
  final bool showTopBorder;
  final bool enabled;
  final VoidCallback onTap;

  const _OptionRow({
    required this.option,
    required this.index,
    required this.selected,
    required this.dimmed,
    required this.showTopBorder,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? kAvaGold.withValues(alpha: 0.10) : null,
            border: Border(
              top: showTopBorder
                  ? const BorderSide(color: kAvaHairline)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? kAvaGold
                      : kAvaSurfaceSecondary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? kAvaGold
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: selected ? kAvaBg : kAvaTextSec,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        color: kAvaOnSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (option.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle,
                        style: const TextStyle(
                          color: kAvaTextSec,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                color: selected ? kAvaGold : kAvaTextSec,
                size: selected ? 20 : 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
