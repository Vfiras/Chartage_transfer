import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/language_service.dart';
import '../notification_controller.dart';
import '../notification_model.dart';

// ── Swipe physics thresholds ──────────────────────────────────────────────────
//
//  0% ──────────── 25% ─────────────── 40%
//  │   free drag  │  resist / preview │ armed → delete on release
//
const double _lockFrac = 0.25;     // Card resistance starts here
const double _deleteFrac = 0.40;   // Visible delete zone width + hard cap
const double _triggerFrac = 0.30;  // Release past here → delete
const double _resistance = 0.55;   // Drag multiplier after lock point (< 1 = harder)

// ─────────────────────────────────────────────────────────────────────────────

class NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final NotificationController controller;
  final VoidCallback onDeleteRequested;

  const NotificationCard({
    super.key,
    required this.item,
    required this.controller,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final gold = AppColors.secondary;
    final isSelected = controller.isSelected(item.id);
    final isUnread = !item.read;
    final inSelectionMode = controller.isSelectionMode;

    return _SwipeToDelete(
      enabled: !inSelectionMode,
      onDeleteTriggered: onDeleteRequested,
      child: GestureDetector(
        onLongPress: inSelectionMode
            ? null
            : () => controller.enterSelectionMode(item.id),
        onTap: () {
          if (inSelectionMode) {
            controller.toggleSelection(item.id);
          } else if (isUnread) {
            controller.markRead(item.id);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isUnread ? AppColors.surface : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? gold.withValues(alpha: 0.6)
                  : isUnread
                      ? AppColors.border
                      : AppColors.softBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              children: [
                if (isUnread)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              gold.withValues(alpha: 0.20),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        width: inSelectionMode ? 32 : 0,
                        child: inSelectionMode
                            ? Padding(
                                padding:
                                    const EdgeInsets.only(right: 12, top: 2),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        isSelected ? gold : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? gold
                                          : AppColors.textMuted,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(Icons.check,
                                          size: 12, color: AppColors.primary)
                                      : null,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      _IconBadge(item: item, read: !isUnread),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title.isNotEmpty
                                        ? item.title
                                        : l.t('notification'),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isUnread
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      fontSize: 15,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _relativeTime(item.createdAt, l),
                                  style: TextStyle(
                                    color: gold.withValues(
                                        alpha: isUnread ? 1.0 : 0.5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.message.isNotEmpty
                                  ? item.message
                                  : l.t('no_details'),
                              style: TextStyle(
                                color: isUnread
                                    ? AppColors.textSecondary
                                    : AppColors.textHint,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            if (_isLiveAlert(item) && isUnread) ...[
                              const SizedBox(height: 12),
                              const _LiveTrackBadge(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _isLiveAlert(NotificationItem item) {
    final text = '${item.title} ${item.message}'.toLowerCase();
    return text.contains('arriving') ||
        text.contains('on the way') ||
        text.contains('minutes away') ||
        text.contains('en route');
  }

  static String _relativeTime(DateTime? dt, LanguageService l) {
    if (dt == null) return l.t('time_now');
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return l.t('time_just_now');
    if (diff.inMinutes < 60) {
      return l.t('time_minutes_ago', args: {'n': diff.inMinutes});
    }
    if (diff.inHours < 24) {
      return l.t('time_hours_ago', args: {'n': diff.inHours});
    }
    if (diff.inDays == 1) return l.t('time_yesterday');
    if (diff.inDays < 7) {
      return l.t('time_days_ago', args: {'n': diff.inDays});
    }
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}';
  }
}

// ── 2-stage swipe-to-delete container ────────────────────────────────────────
//
//  Stage 1 (0→25%): free drag, card reveals delete zone, springs back on release
//  Stage 2 (25→40%): rubber-band resistance, haptic at 40%, delete on release
//
class _SwipeToDelete extends StatefulWidget {
  final Widget child;
  final VoidCallback onDeleteTriggered;
  final bool enabled; // false during selection mode

  const _SwipeToDelete({
    required this.child,
    required this.onDeleteTriggered,
    required this.enabled,
  });

  @override
  State<_SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<_SwipeToDelete>
    with SingleTickerProviderStateMixin {
  // Unbounded so value can range freely below 0 (left offset in pixels)
  late final AnimationController _ctrl;
  double _cardWidth = 0;
  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this)
      ..addListener(_rebuild);
  }

  @override
  void dispose() {
    _ctrl
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SwipeToDelete old) {
    super.didUpdateWidget(old);
    // Entering selection mode while card is swiped open → spring it back
    if (old.enabled && !widget.enabled && _ctrl.value < -1) {
      _springToZero();
    }
  }

  void _rebuild() => setState(() {});

  // ── Gesture callbacks ───────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails _) {
    if (!widget.enabled) return;
    _ctrl.stop();
    _hapticFired = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _cardWidth <= 0) return;

    final lockPx = -_cardWidth * _lockFrac;
    final deletePx = -_cardWidth * _deleteFrac;

    double next = _ctrl.value + details.delta.dx;

    // ① Never swipe right past 0
    if (next > 0) next = 0;

    // ② Rubber-band resistance after lock point (25%)
    if (next < lockPx) {
      final excess = next - lockPx;
      next = lockPx + excess * _resistance;
    }

    // ③ Hard cap: visual max is deleteFrac (40%)
    if (next < deletePx) next = deletePx;

    _ctrl.value = next;

    // ④ Single haptic pulse the moment the trigger threshold is armed
    final triggerPx = -_cardWidth * _triggerFrac;
    if (!_hapticFired && _ctrl.value <= triggerPx + 0.5) {
      HapticFeedback.mediumImpact();
      _hapticFired = true;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    final triggerPx = -_cardWidth * _triggerFrac;
    final flingLeft = details.velocity.pixelsPerSecond.dx < -800;

    if (_ctrl.value <= triggerPx + 0.5 || flingLeft) {
      // Past trigger on release (or a fast left fling) — commit delete
      _doDelete();
    } else {
      // Otherwise spring back with finger velocity for realistic feel
      _springToZero(velocity: details.velocity.pixelsPerSecond.dx);
    }
  }

  // ── Animation helpers ───────────────────────────────────────────────────────

  void _springToZero({double velocity = 0}) {
    final sim = SpringSimulation(
      const SpringDescription(
        mass: 1.0,
        stiffness: 600.0, // snappy
        damping: 38.0,    // minimal oscillation
      ),
      _ctrl.value,
      0.0,
      velocity,
    );
    _ctrl.animateWith(sim);
  }

  Future<void> _doDelete() async {
    // Sweep card fully off to the left, then hand off to parent
    await _ctrl.animateTo(
      -_cardWidth,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInCubic,
    );
    widget.onDeleteTriggered();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final offset = _ctrl.value; // always <= 0

    // Progress is 0→1 over the trigger range (controls bg color, icon, label)
    final deleteProgress = _cardWidth > 0
        ? ((-offset) / (_cardWidth * _triggerFrac)).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          _cardWidth = constraints.maxWidth;
          final bgWidth = _cardWidth * _deleteFrac;

          return GestureDetector(
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            // Claim gesture early so scrollview defers if horizontal intent is clear
            behavior: HitTestBehavior.opaque,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // ── Delete background — fixed at right 40%, card slides over it ──
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: bgWidth,
                    child: _DeleteBackground(progress: deleteProgress),
                  ),

                  // ── Card — translates left, always occludes background at rest ───
                  Transform.translate(
                    offset: Offset(offset, 0),
                    child: widget.child,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Delete background ─────────────────────────────────────────────────────────

class _DeleteBackground extends StatelessWidget {
  final double progress; // 0.0 → just peeking, 1.0 → armed

  const _DeleteBackground({required this.progress});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final bgColor = Color.lerp(
      const Color(0xFF5C0008),
      const Color(0xFFB50010),
      Curves.easeIn.transform(progress),
    )!;

    final armed = progress >= 0.95;
    final contentOpacity = ((progress - 0.3) / 0.3).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      child: Opacity(
        opacity: contentOpacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              armed ? Icons.delete_rounded : Icons.delete_outline_rounded,
              color: const Color(0xFFFFDAD6),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              l.t('delete'),
              style: const TextStyle(
                color: Color(0xFFFFDAD6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Icon badge ────────────────────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  final NotificationItem item;
  final bool read;

  const _IconBadge({required this.item, required this.read});

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.secondary;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: gold.withValues(alpha: read ? 0.07 : 0.13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: gold.withValues(alpha: read ? 0.08 : 0.20),
            ),
          ),
          child: Icon(
            _iconFor(item),
            color: gold.withValues(alpha: read ? 0.55 : 1.0),
            size: 22,
          ),
        ),
        if (!read)
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: gold,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  static IconData _iconFor(NotificationItem item) {
    final text = '${item.title} ${item.message}'.toLowerCase();
    if (text.contains('driver') ||
        text.contains('chauffeur') ||
        text.contains('arriving') ||
        text.contains('ride')) {
      return Icons.directions_car_filled_outlined;
    }
    if (text.contains('tier') ||
        text.contains('status') ||
        text.contains('reward') ||
        text.contains('promo') ||
        text.contains('gold')) {
      return Icons.workspace_premium_outlined;
    }
    if (text.contains('cancel')) {
      return Icons.event_busy_outlined;
    }
    if (text.contains('booking') ||
        text.contains('reservation') ||
        text.contains('confirmed') ||
        text.contains('received') ||
        text.contains('journey')) {
      return Icons.event_available_outlined;
    }
    if (text.contains('concierge') ||
        text.contains('support') ||
        text.contains('response') ||
        text.contains('team')) {
      return Icons.headset_mic_outlined;
    }
    return Icons.notifications_none_rounded;
  }
}

// ── Live track badge ──────────────────────────────────────────────────────────

class _LiveTrackBadge extends StatelessWidget {
  const _LiveTrackBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2E5A2E)),
      ),
      child: const Text(
        'LIVE TRACK',
        style: TextStyle(
          color: Color(0xFF5CDB5C),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
