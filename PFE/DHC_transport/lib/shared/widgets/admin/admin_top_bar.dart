import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// The single header used by every admin screen — tabs and pushed screens
/// alike.
///
/// Layout follows the admin design language: a compact bar with an optional
/// back affordance and title on the left, and actions on the right, separated
/// from the content by a hairline.
///
///   [back?]  Title            [bell + badge?]  [action?]
///            subtitle?
///
/// The bell is only rendered when [onNotificationTap] is supplied, so a screen
/// that has nowhere to send the user never shows a dead control.
class AdminTopBar extends StatelessWidget {
  /// Page title, e.g. "Bookings".
  final String title;

  /// Small secondary line under the title — used by detail screens to show the
  /// record id.
  final String? subtitle;

  /// Opens the notifications screen. Omit to hide the bell entirely.
  final VoidCallback? onNotificationTap;

  /// Unread badge count. 0 hides the badge.
  final int unreadCount;

  /// Show a back arrow — for pushed screens (Promotions, Pricing, …).
  final bool showBack;

  /// Defaults to popping the current route when [showBack] is set.
  final VoidCallback? onBackTap;

  /// Optional trailing action, e.g. the edit pencil on a detail screen.
  final Widget? action;

  const AdminTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onNotificationTap,
    this.unreadCount = 0,
    this.showBack = false,
    this.onBackTap,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8DDCD);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: hairline)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(showBack ? 8 : 20, 12, 12, 12),
          child: Row(
            children: [
              if (showBack)
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded,
                      color: AppColors.textPrimary, size: 23),
                  splashRadius: 22,
                  onPressed:
                      onBackTap ?? () => Navigator.of(context).maybePop(),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (onNotificationTap != null)
                _BellButton(
                  unreadCount: unreadCount,
                  onTap: onNotificationTap!,
                ),
              if (action != null) ...[
                const SizedBox(width: 4),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _BellButton({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.notifications_none_rounded,
                color: AppColors.textPrimary, size: 23),
            if (unreadCount > 0)
              Positioned(
                top: -3,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: AppColors.background, width: 1.5),
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w800,
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
