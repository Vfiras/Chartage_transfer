import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/language_service.dart';
import '../../core/services/push_notification_service.dart';
import 'notification_controller.dart';
import 'notification_model.dart';
import 'widgets/empty_notifications_widget.dart';
import 'widgets/notification_card.dart';
import 'widgets/notification_section.dart';

/// Pushed from the bell in [ClientTopBar] — it used to be the 5th shell tab,
/// which is why it still reports its unread count upward for the badge.
class NotificationsScreen extends StatefulWidget {
  final ValueChanged<int> onUnreadCountChanged;

  const NotificationsScreen({
    super.key,
    required this.onUnreadCountChanged,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = NotificationController()
      ..onUnreadCountChanged = widget.onUnreadCountChanged
      ..addListener(_onControllerUpdate)
      ..load();
    // Android 13+ will not post anything until POST_NOTIFICATIONS is granted.
    // Asked here rather than at cold start so the system prompt arrives while
    // the user is actually looking at their notifications. The plugin only
    // shows the dialog once; later calls return the standing answer.
    PushNotificationService.instance.requestPermission();
  }

  @override
  void dispose() {
    _ctrl
      ..removeListener(_onControllerUpdate)
      ..dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  // ── Delete with undo ────────────────────────────────────────────────────────

  void _handleDeleteRequest(NotificationItem item) {
    HapticFeedback.mediumImpact();
    final removed = _ctrl.removeLocally(item.id);
    if (removed == null) return;
    final l = LanguageService.instance;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    bool undone = false;

    messenger
        .showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            duration: const Duration(seconds: 4),
            content: Text(
              l.t('notification_deleted'),
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
            ),
            action: SnackBarAction(
              label: l.t('undo'),
              textColor: AppColors.secondary,
              onPressed: () {
                undone = true;
                _ctrl.restoreItem(removed);
              },
            ),
          ),
        )
        .closed
        .then((_) {
      if (!undone) _ctrl.commitDelete(removed.id);
    });
  }

  // ── Multi-select delete ─────────────────────────────────────────────────────

  void _handleDeleteSelected() {
    HapticFeedback.mediumImpact();
    _ctrl.deleteSelected();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    final l = LanguageService.instance;
    final inSelectionMode = _ctrl.isSelectionMode;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ────────────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.15),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: inSelectionMode
                  ? _SelectionAppBar(
                      key: const ValueKey('selection'),
                      controller: _ctrl,
                      onDeleteSelected: _handleDeleteSelected,
                    )
                  : _DefaultAppBar(
                      key: const ValueKey('default'),
                      hasUnread: _ctrl.hasUnread,
                      onMarkAllRead: _ctrl.markAllRead,
                    ),
            ),

            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppColors.secondary,
                backgroundColor: AppColors.surfaceElevated,
                onRefresh: _ctrl.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 110),
                  children: [
                    // Hero title
                    const SizedBox(height: 20),
                    Text(
                      l.t('alerts'),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l.t('alerts_hero_subtitle'),
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Body
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      child: _ctrl.loading
                          ? Padding(
                              padding: const EdgeInsets.all(48),
                              child: Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.secondary),
                              ),
                            )
                          : _ctrl.items.isEmpty
                              ? const EmptyNotificationsWidget()
                              : _GroupedList(
                                  controller: _ctrl,
                                  onDeleteRequested: _handleDeleteRequest,
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Default app bar ─────────────────────────────────────────────────────────────

class _DefaultAppBar extends StatelessWidget {
  final bool hasUnread;
  final VoidCallback onMarkAllRead;

  const _DefaultAppBar({
    super.key,
    required this.hasUnread,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Back arrow: this is a pushed screen now, not a tab.
            IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary, size: 22),
              onPressed: () => Navigator.of(context).maybePop(),
              splashRadius: 22,
            ),
            Expanded(
              child: Text(
                l.t('notifications'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (hasUnread)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: onMarkAllRead,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.25),
                          width: 1),
                    ),
                    child: Icon(
                      Icons.done_all_rounded,
                      color: AppColors.secondary,
                      size: 16,
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

// ── Selection app bar ───────────────────────────────────────────────────────────

class _SelectionAppBar extends StatelessWidget {
  final NotificationController controller;
  final VoidCallback onDeleteSelected;

  const _SelectionAppBar({
    super.key,
    required this.controller,
    required this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final count = controller.selectedCount;
    final allSelected = controller.allSelected;

    return Container(
      height: 56,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: AppColors.textPrimary),
            onPressed: controller.exitSelectionMode,
            splashRadius: 20,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              l.t('selected_count', args: {'count': count}),
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: controller.toggleSelectAll,
            child: Text(
              allSelected ? l.t('deselect_all') : l.t('select_all'),
              style: TextStyle(
                color: AppColors.secondary.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (count > 0)
            IconButton(
              icon: Icon(Icons.mark_email_read_outlined,
                  color: AppColors.textPrimary, size: 22),
              tooltip: l.t('mark_read'),
              onPressed: controller.markSelectedRead,
              splashRadius: 20,
            ),
          if (count > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFFFB4AB), size: 22),
              tooltip: l.t('delete_selected'),
              onPressed: onDeleteSelected,
              splashRadius: 20,
            ),
        ],
      ),
    );
  }
}

// ── Grouped list ────────────────────────────────────────────────────────────────

class _GroupedList extends StatelessWidget {
  final NotificationController controller;
  final ValueChanged<NotificationItem> onDeleteRequested;

  const _GroupedList({
    required this.controller,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final today = controller.todayItems;
    final yesterday = controller.yesterdayItems;
    final earlier = controller.earlierItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (today.isNotEmpty) ...[
          NotificationSection(label: l.t('today'), isToday: true),
          ..._cards(today),
        ],
        if (yesterday.isNotEmpty) ...[
          const SizedBox(height: 24),
          NotificationSection(label: l.t('yesterday')),
          ..._cards(yesterday),
        ],
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: 24),
          NotificationSection(label: l.t('earlier')),
          ..._cards(earlier),
        ],
      ],
    );
  }

  List<Widget> _cards(List<NotificationItem> items) => items
      .map(
        (item) => NotificationCard(
          key: ValueKey(item.id),
          item: item,
          controller: controller,
          onDeleteRequested: () => onDeleteRequested(item),
        ),
      )
      .toList();
}
