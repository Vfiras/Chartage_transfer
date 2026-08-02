import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../features/notifications/notifications_screen.dart';
import '../../../shared/widgets/admin/admin_nav_bar.dart';
import 'admin_bookings_screen.dart';
import 'admin_cars_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_pricing_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_promotions_screen.dart';
import 'admin_suppliers_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  /// Admins receive real notifications (a cash booking fans out to every admin),
  /// so the shell owns the count and hands it to each tab's [AdminTopBar].
  Future<void> _loadUnread() async {
    if (!AuthService.instance.isAuthenticated) return;
    try {
      final items = await const NotificationService().listNotifications();
      final count = items.where((n) => n['read'] != true).length;
      if (mounted && count != _unreadCount) {
        setState(() => _unreadCount = count);
      }
    } catch (_) {
      // Badge is cosmetic — a failed fetch must never break the shell.
    }
  }

  void _setIndex(int value) => setState(() => _index = value);

  void _openNotifications() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(
              onUnreadCountChanged: (count) {
                if (mounted && count != _unreadCount) {
                  setState(() => _unreadCount = count);
                }
              },
            ),
          ),
        )
        .then((_) => _loadUnread());
  }

  void _pushPromotions() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminPromotionsScreen()),
    );
  }

  void _pushPricing() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminPricingScreen()),
    );
  }

  void _pushComplaints() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminComplaintsScreen()),
    );
  }

  void _pushSuppliers() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminSuppliersScreen()),
    );
  }

  void _pushRecommendations() {
    Navigator.of(context).pushNamed(AppRoutes.recommendationManagement);
  }

  @override
  Widget build(BuildContext context) {
    // Each tab renders its own AdminTopBar (the design puts the page title in
    // the screen, not the shell), so the shell only passes the bell wiring.
    final tabs = [
      AdminDashboardScreen(
        unreadCount: _unreadCount,
        onOpenNotifications: _openNotifications,
        onOpenBookings: () => _setIndex(1),
        onOpenFleet: () => _setIndex(2),
        onOpenPromotions: _pushPromotions,
        onOpenPricing: _pushPricing,
        onOpenComplaints: _pushComplaints,
        onOpenSuppliers: _pushSuppliers,
        onOpenRecommendations: _pushRecommendations,
      ),
      AdminBookingsScreen(
        unreadCount: _unreadCount,
        onOpenNotifications: _openNotifications,
      ),
      AdminCarsScreen(
        unreadCount: _unreadCount,
        onOpenNotifications: _openNotifications,
      ),
      AdminProfileScreen(
        unreadCount: _unreadCount,
        onOpenNotifications: _openNotifications,
      ),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: AppColors.background,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        // extendBody lets content scroll behind the floating pill, matching
        // the client shell's treatment of the same nav.
        extendBody: true,
        body: IndexedStack(index: _index, children: tabs),
        // No nav badge: unread lives on the bell in AdminTopBar, so duplicating
        // it on a tab would point the admin at the wrong control.
        bottomNavigationBar: AdminNavBar(
          index: _index,
          onChanged: _setIndex,
        ),
      ),
    );
  }
}
