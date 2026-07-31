import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../widgets/common/fallback_network_image.dart';

/// The single top-bar pattern shared by every client tab (Home, Trips, Saved,
/// Profile).
///
/// Left  = the user's avatar   → switches to the Profile tab.
/// Right = a notification bell → pushes the Notifications screen.
///
/// Before this existed each tab rolled its own header: Home's avatar opened
/// alerts (not the profile) and two tabs carried a hamburger that did nothing.
class ClientTopBar extends StatelessWidget {
  /// Unread notification count — drives the bell badge. 0 hides the badge.
  final int unreadCount;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;

  /// Centre wordmark. Defaults to the brand.
  final String title;

  /// Renders light-on-dark regardless of theme — for bars sitting on top of a
  /// dark photographic hero (the Home tab).
  final bool onDarkHero;

  /// Set to 0 when the bar is nested inside an already-padded scroll view, so
  /// the gutter isn't applied twice.
  final double horizontalPadding;

  const ClientTopBar({
    super.key,
    this.unreadCount = 0,
    this.onProfileTap,
    this.onNotificationTap,
    this.title = 'CARTHAGE TRANSFER',
    this.onDarkHero = false,
    this.horizontalPadding = 22,
  });

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.secondary;
    final iconColor = onDarkHero ? Colors.white : AppColors.textPrimary;
    final avatarUrl = AuthService.instance.currentUser?.avatarUrl;

    return SizedBox(
      height: 56,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          children: [
            // ── Left: avatar → Profile tab ──────────────────────────────
            GestureDetector(
              onTap: onProfileTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: gold.withValues(alpha: 0.55)),
                ),
                child: ClipOval(
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Container(
                          color: onDarkHero
                              ? Colors.black.withValues(alpha: 0.45)
                              : AppColors.surfaceElevated,
                          alignment: Alignment.center,
                          child: Icon(Icons.person_rounded,
                              color: gold, size: 20),
                        )
                      : FallbackNetworkImage(
                          url: avatarUrl, fit: BoxFit.cover),
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            // ── Right: bell + unread badge → Notifications ──────────────
            GestureDetector(
              onTap: onNotificationTap,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: onDarkHero
                          ? Colors.black.withValues(alpha: 0.45)
                          : AppColors.surfaceElevated,
                      border: Border.all(
                        color: onDarkHero
                            ? Colors.white.withValues(alpha: 0.15)
                            : AppColors.border,
                      ),
                    ),
                    child: Icon(Icons.notifications_none_rounded,
                        color: iconColor, size: 21),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        constraints: const BoxConstraints(minWidth: 18),
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: onDarkHero
                                ? Colors.black
                                : AppColors.background,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
