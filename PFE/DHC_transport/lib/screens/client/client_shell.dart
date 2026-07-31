import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/constants/app_colors.dart';
import '../../core/constants/maps_config.dart';
import '../../core/services/places_service.dart';
import '../../core/models/favorite_location.dart';
import '../../core/models/transport_trip.dart';
import '../../core/models/user_model.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/favorite_memories_service.dart';
import '../../core/services/favorite_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/pricing_service.dart';
import '../../core/services/reward_service.dart';
import '../../core/services/trip_service.dart';
import '../../core/services/vehicle_catalog_service.dart';
import '../../data/fleet_data.dart';
import '../../data/travel_tips_data.dart';
import '../assistant/widgets/ava_avatar.dart';
import '../../models/booking_data.dart';
import '../../models/vehicle.dart';
import '../../models/fleet_item.dart';
import '../../shared/widgets/common/luxury_components.dart';
import '../../shared/widgets/client/client_top_bar.dart';
import '../../shared/widgets/client/premium_client_components.dart';
import '../../shared/widgets/client/premium_profile_components.dart';
import '../../widgets/common/fallback_network_image.dart';
import '../../widgets/common/luxury_skeleton.dart';
import '../../features/notifications/notifications_screen.dart';
import '../assistant_screen.dart';
import '../booking_fleet_screen.dart';
import '../booking_search_screen.dart';
import '../edit_profile_screen.dart';
import '../vehicles_screen.dart';

const _homeLightSurfaceColor = Color(0xFFFFFEFA);
const _homeLightBorderColor = Color(0xFFF0E4D8);

bool _isLightMode(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

Color _homeSurfaceColor(BuildContext context) =>
    _isLightMode(context) ? _homeLightSurfaceColor : AppColors.surface;

Color _homeBorderColor(BuildContext context) =>
    _isLightMode(context) ? _homeLightBorderColor : AppColors.border;

class ClientShell extends StatefulWidget {
  final int initialIndex;

  const ClientShell({super.key, this.initialIndex = 0});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

/// Tab indices, in nav order: Home 0 · Bookings 1 · AVA 2 · Favorites 3 ·
/// Profile 4. AVA sits in the centre; Alerts is no longer a tab (the bell in
/// [ClientTopBar] pushes the notifications screen instead).
class _Tab {
  static const home = 0;
  static const ava = 2;
  static const profile = 4;
}

class _ClientShellState extends State<ClientShell> {
  late int _index;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4).toInt();
    _loadUnread();
  }

  /// The Alerts tab used to own the unread count and report it upward. Now that
  /// notifications are a pushed screen, the shell fetches the count itself so
  /// every tab's bell badge stays accurate without one always being mounted.
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

  void _startBooking(BookingData data) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingFleetScreen(data: data)),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openProfileTab() => setState(() => _index = _Tab.profile);

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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageService.instance.language,
      builder: (context, language, _) => _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);

    final tabs = [
      _ClientHomeTab(
        unreadCount: _unreadCount,
        onStartBooking: _startBooking,
        onOpenVehicles: () => _push(const VehiclesScreen()),
        onOpenNotifications: _openNotifications,
        onOpenProfile: _openProfileTab,
        onOpenAva: () => setState(() => _index = _Tab.ava),
      ),
      _BookingsTab(
        onNavigateToProfile: _openProfileTab,
        onOpenNotifications: _openNotifications,
        unreadCount: _unreadCount,
      ),
      // AVA lives in the stack so its chat state survives tab switches.
      AssistantScreen(onBack: () => setState(() => _index = _Tab.home)),
      _FavoritesTab(
        onNavigateToProfile: _openProfileTab,
        onOpenNotifications: _openNotifications,
        unreadCount: _unreadCount,
      ),
      _ProfileTab(
        onOpenNotifications: _openNotifications,
        unreadCount: _unreadCount,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: LuxuryBackdrop(child: IndexedStack(index: _index, children: tabs)),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: (value) => setState(() => _index = value),
      ),
    );
  }
}

class _ClientHomeTab extends StatelessWidget {
  final int unreadCount;
  final ValueChanged<BookingData> onStartBooking;
  final VoidCallback onOpenVehicles;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenAva;

  const _ClientHomeTab({
    required this.unreadCount,
    required this.onStartBooking,
    required this.onOpenVehicles,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    required this.onOpenAva,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isGuest = AuthService.instance.isGuest;
    final firstName =
        isGuest ? 'Guest' : (user?.name.split(' ').first ?? '').trim();
    final hour = DateTime.now().hour;
    final l = LanguageService.instance;
    final greeting = hour < 12
        ? l.t('good_morning')
        : (hour < 17 ? l.t('good_afternoon') : l.t('good_evening'));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeHero(
              firstName: firstName,
              greeting: greeting,
              unreadCount: unreadCount,
              onOpenNotifications: onOpenNotifications,
              onOpenProfile: onOpenProfile,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 190),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isGuest) ...[
                    _GuestNotice(onLogin: () => _goLogin(context)),
                    const SizedBox(height: 14),
                  ],
                  _AvaHomeCard(onOpenAva: onOpenAva),
                  const SizedBox(height: 22),
                  _WhereToCard(
                    onBookNow: () => _openBooking(context),
                  ),
                  const SizedBox(height: 28),
                  _HomeFleetSection(onViewAll: onOpenVehicles),
                  const SizedBox(height: 28),
                  // Deliberately not const: a const instance is canonicalised,
                  // so Flutter skips rebuilding it when the language notifier
                  // fires and the section header would stay in English.
                  _TravelTipsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBooking(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingSearchScreen(onSearch: onStartBooking),
      ),
    );
  }

  void _goLogin(BuildContext context) {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }
}

// ─── AVA quick access (Home) ──────────────────────────────────────────────────

/// Tap opens AVA; press-and-hold dictates a question and opens AVA with it
/// already sent. Uses the same `speech_to_text` pipeline as the chat input bar.
class _AvaHomeCard extends StatefulWidget {
  final VoidCallback onOpenAva;

  const _AvaHomeCard({required this.onOpenAva});

  @override
  State<_AvaHomeCard> createState() => _AvaHomeCardState();
}

class _AvaHomeCardState extends State<_AvaHomeCard> {
  final _speech = stt.SpeechToText();
  bool _listening = false;
  String _transcript = '';

  @override
  void dispose() {
    if (_listening) _speech.cancel();
    super.dispose();
  }

  Future<void> _startListening() async {
    final available = await _speech.initialize();
    if (!available || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _listening = true;
      _transcript = '';
    });
    await _speech.listen(
      onResult: (result) {
        if (mounted) setState(() => _transcript = result.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _stopAndSend() async {
    if (!_listening) return;
    await _speech.stop();
    if (!mounted) return;
    final text = _transcript.trim();
    setState(() => _listening = false);
    HapticFeedback.lightImpact();
    if (text.isEmpty) {
      widget.onOpenAva();
      return;
    }
    // Push AVA with the dictated question already on its way.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AssistantScreen(initialMessage: text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final light = _isLightMode(context);

    return GestureDetector(
      onTap: widget.onOpenAva,
      onLongPress: _startListening,
      onLongPressEnd: (_) => _stopAndSend(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: light
                ? [const Color(0xFFFFF7E8), const Color(0xFFFBF1E8)]
                : [const Color(0xFF191510), const Color(0xFF0C0A07)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.secondary
                .withValues(alpha: _listening ? 0.75 : 0.32),
            width: _listening ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary
                  .withValues(alpha: _listening ? 0.30 : 0.12),
              blurRadius: _listening ? 26 : 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.55)),
              ),
              child: const AvaAvatar(size: 46, borderWidth: 0),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _listening ? l.t('ava_listening') : l.t('ava_home_title'),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _listening && _transcript.isNotEmpty
                        ? _transcript
                        : l.t('ava_home_subtitle'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _listening && _transcript.isNotEmpty
                          ? AppColors.secondary
                          : AppColors.textMuted,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _listening
                    ? AppColors.secondary
                    : AppColors.secondary.withValues(alpha: 0.14),
              ),
              child: Icon(
                _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _listening
                    ? const Color(0xFF221A08)
                    : AppColors.secondary,
                size: 21,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fleet preview (Home) ─────────────────────────────────────────────────────

/// Horizontally scrolling vehicle cards on the Home tab.
///
/// Live data: `VehicleCatalogService` hits `GET /cars/` (available vehicles
/// only) and falls back to the bundled catalogue if the call fails, so the
/// section always renders something. Prices are the vehicle's `base_price`
/// (= the initial fee) in EUR, labelled "from" because the real total depends
/// on route distance.
class _HomeFleetSection extends StatefulWidget {
  final VoidCallback onViewAll;

  const _HomeFleetSection({required this.onViewAll});

  @override
  State<_HomeFleetSection> createState() => _HomeFleetSectionState();
}

class _HomeFleetSectionState extends State<_HomeFleetSection> {
  late Future<List<Vehicle>> _future;

  @override
  void initState() {
    super.initState();
    _future = const VehicleCatalogService().listVehicles();
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('our_fleet'),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l.t('our_fleet_subtitle'),
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: widget.onViewAll,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(
                    l.t('view_all'),
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: AppColors.secondary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 232,
          child: FutureBuilder<List<Vehicle>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, __) => const SkeletonPulse(
                    child: SkeletonBox(width: 168, height: 232, radius: 20),
                  ),
                );
              }
              final vehicles = snapshot.data ?? const <Vehicle>[];
              if (vehicles.isEmpty) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.t('no_vehicles'),
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                );
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                padding: EdgeInsets.zero,
                itemCount: vehicles.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _HomeFleetCard(
                  vehicle: vehicles[i],
                  onTap: widget.onViewAll,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HomeFleetCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onTap;

  const _HomeFleetCard({required this.vehicle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final light = _isLightMode(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          color: _homeSurfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _homeBorderColor(context)),
          boxShadow: light
              ? [
                  BoxShadow(
                    color: const Color(0x103B2A10),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: 104,
                width: double.infinity,
                color: Colors.white,
                child: vehicle.image.startsWith('assets')
                    ? Image.asset(vehicle.image, fit: BoxFit.contain)
                    : FallbackNetworkImage(
                        url: vehicle.image, fit: BoxFit.contain),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        vehicle.category.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      l.t('from_price'),
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                    Text(
                      '${vehicle.price} EUR',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.groups_rounded,
                            color: AppColors.textMuted, size: 13),
                        const SizedBox(width: 3),
                        Text('${vehicle.seatCount}',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 10.5)),
                        const SizedBox(width: 9),
                        Icon(Icons.luggage_rounded,
                            color: AppColors.textMuted, size: 13),
                        const SizedBox(width: 3),
                        Text('${vehicle.bags}',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 10.5)),
                      ],
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

// ─── Travel tips (Home) ───────────────────────────────────────────────────────

/// Horizontally scrolling cards curated from the AVA knowledge base.
class _TravelTipsSection extends StatelessWidget {
  const _TravelTipsSection();

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('travel_tips'),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l.t('travel_tips_subtitle'),
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.zero,
            itemCount: kTravelTips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _TravelTipCard(tip: kTravelTips[i]),
          ),
        ),
      ],
    );
  }
}

class _TravelTipCard extends StatelessWidget {
  final TravelTip tip;

  const _TravelTipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 214,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _homeSurfaceColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _homeBorderColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tip.categoryLabel.toUpperCase(),
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 11),
            Text(
              tip.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Expanded(
              child: Text(
                tip.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  LanguageService.instance.t('read_more'),
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(Icons.arrow_forward_rounded,
                    size: 13, color: AppColors.secondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    final l = LanguageService.instance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tip.categoryLabel.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tip.title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    tip.body,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AssistantScreen(initialMessage: tip.avaQuestion),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: const Color(0xFF221A08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  label: Text(
                    l.t('ask_ava'),
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  final String firstName;
  final String greeting;
  final int unreadCount;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;

  const _HomeHero({
    required this.firstName,
    required this.greeting,
    required this.unreadCount,
    required this.onOpenNotifications,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.48)
        .clamp(390.0, 520.0)
        .toDouble();
    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/Gemini_Generated_Image_e8gc14e8gc14e8gc.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A0F00), Color(0xFF050202)],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0x33000000),
                  const Color(0xCC000000),
                  Colors.black,
                ],
                stops: const [0.0, 0.58, 1.0],
              ),
            ),
          ),
          // Shared top bar: avatar → Profile, bell → Notifications. Replaces
          // the old header whose avatar opened alerts and whose hamburger did
          // nothing at all.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: ClientTopBar(
                unreadCount: unreadCount,
                onProfileTap: onOpenProfile,
                onNotificationTap: onOpenNotifications,
                onDarkHero: true,
              ),
            ),
          ),
          Positioned(
            bottom: 28,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LanguageService.instance.t('experience_excellence'),
                  style: TextStyle(
                    color: Color(0xFFC8A96B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$greeting, $firstName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
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

class _WhereToCard extends StatelessWidget {
  final VoidCallback onBookNow;

  const _WhereToCard({required this.onBookNow});

  @override
  Widget build(BuildContext context) {
    final light = _isLightMode(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: light ? _homeSurfaceColor(context) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _homeBorderColor(context)),
        boxShadow: [
          BoxShadow(
            color: light
                ? const Color(0x183B2A10)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: light ? 24 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.location_on_rounded,
                    color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LanguageService.instance.t('your_destination'),
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    LanguageService.instance.t('where_to'),
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onBookNow,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                LanguageService.instance.t('book_now'),
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestNotice extends StatelessWidget {
  final VoidCallback onLogin;

  const _GuestNotice({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return LuxuryCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child:
                Icon(Icons.lock_outline_rounded, color: AppColors.accentText),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.t('login_to_reserve'),
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: onLogin,
            child: Text(l.t('login'),
                style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Explore Tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ExploreTab extends StatefulWidget {
  const _ExploreTab();

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  String _active = 'All';

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    final user = AuthService.instance.currentUser;
    final isGuest = AuthService.instance.isGuest;
    final filtered = _active == 'All'
        ? FleetData.items
        : FleetData.items.where((e) => e.category == _active).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(Icons.menu_rounded,
                      color: AppColors.accentText, size: 20),
                ),
                Expanded(
                  child: Text(
                    'Carthage Transfer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.secondary, width: 1.5),
                  ),
                  child: ClipOval(
                    child: !isGuest && user?.avatarUrl != null
                        ? FallbackNetworkImage(
                            url: user!.avatarUrl!, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.surface,
                            child: Icon(Icons.person_rounded,
                                color: AppColors.secondary, size: 22),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'EXECUTIVE SELECTION',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Premium Fleet',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: FleetData.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = FleetData.categories[i];
                  final selected = cat == _active;
                  return GestureDetector(
                    onTap: () => setState(() => _active = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color:
                            selected ? AppColors.secondary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              selected ? AppColors.secondary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            for (final item in filtered) _ExploreFleetCard(item: item),
          ],
        ),
      ),
    );
  }
}

class _ExploreFleetCard extends StatelessWidget {
  final FleetItem item;

  const _ExploreFleetCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.asset(
              item.image,
              height: 190,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 190,
                color: AppColors.surfaceElevated,
                child: Icon(Icons.directions_car_rounded,
                    color: AppColors.textMuted, size: 64),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            item.comfort.toUpperCase(),
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.price,
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '/ per hour',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SpecChip(
                        icon: Icons.groups_rounded, label: 'Up to ${item.pax}'),
                    _SpecChip(
                        icon: Icons.luggage_rounded,
                        label: '${item.bags} Bags'),
                    ...item.features.take(1).map(
                          (f) => _SpecChip(
                              icon: Icons.star_outline_rounded, label: f),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SpecChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Floating Bottom Navigation Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _BottomNav({
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumClientNav(
      index: index,
      onChanged: onChanged,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 22),
    );
  }
}

class _BookingsTab extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onOpenNotifications;
  final int unreadCount;

  const _BookingsTab({
    this.onNavigateToProfile,
    this.onOpenNotifications,
    this.unreadCount = 0,
  });

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

const _bookingFilters = ['Upcoming', 'History', 'Canceled'];

class _BookingsTabState extends State<_BookingsTab> {
  /// Index into [_bookingFilters]; kept in sync both ways with [_pageCtrl] so
  /// tapping a tab animates the pages and swiping updates the underline.
  int _filterIndex = 0;
  late final PageController _pageCtrl;
  late Future<_BookingsPayload> _future;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _future = _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<_BookingsPayload> _load() async {
    final history = await const TripService().history();
    final rules = await const PricingService().rules();
    return _BookingsPayload(history: history, rules: rules);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _selectFilter(int index) {
    if (index == _filterIndex) return;
    setState(() => _filterIndex = index);
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;

    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: FutureBuilder<_BookingsPayload>(
          future: _future,
          builder: (context, snapshot) {
            final payload = snapshot.data;
            final upcoming = payload?.history['upcoming'] ?? const [];
            final past = payload?.history['past'] ?? const [];
            final cancelled =
                past.where((t) => t.status == 'cancelled').toList();
            final loading =
                snapshot.connectionState == ConnectionState.waiting;
            final rules = payload?.rules ?? const PricingRules();

            // Header stays put; only the list area pages, so a horizontal
            // swipe moves between Upcoming / History / Canceled.
            return Column(
              children: [
                ClientTopBar(
                  unreadCount: widget.unreadCount,
                  onProfileTap: widget.onNavigateToProfile,
                  onNotificationTap: widget.onOpenNotifications,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('my_rides'),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.t('rides_hero_subtitle'),
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: AppColors.softBorder, width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < _bookingFilters.length; i++)
                              GestureDetector(
                                onTap: () => _selectFilter(i),
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  margin: const EdgeInsets.only(right: 20),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _filterIndex == i
                                            ? AppColors.secondary
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    _bookingFilterLabel(_bookingFilters[i]),
                                    style: TextStyle(
                                      color: _filterIndex == i
                                          ? AppColors.secondary
                                          : AppColors.textMuted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
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
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    onPageChanged: (i) => setState(() => _filterIndex = i),
                    children: [
                      _tripPage(upcoming, rules, loading, 'Upcoming'),
                      _tripPage(past, rules, loading, 'History'),
                      _tripPage(cancelled, rules, loading, 'Canceled'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tripPage(
    List<TransportTrip> trips,
    PricingRules rules,
    bool loading,
    String filter,
  ) {
    return RefreshIndicator(
      color: AppColors.secondary,
      backgroundColor: AppColors.surfaceElevated,
      onRefresh: () async => _reload(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 130),
        children: [
          if (loading)
            // Skeletons shaped like trip cards, not a spinner.
            const SkeletonCardList(
              count: 3,
              cardHeight: 148,
              padding: EdgeInsets.zero,
            )
          else if (trips.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.softBorder),
              ),
              child: Text(
                _emptyRidesMessage(filter),
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            )
          else
            for (final trip in trips)
              _BookingCard(
                trip: trip,
                rules: rules,
                onChanged: _reload,
              ),
        ],
      ),
    );
  }

  String _bookingFilterLabel(String value) {
    final l = LanguageService.instance;
    return switch (value) {
      'History' => l.t('history'),
      'Canceled' => l.t('canceled'),
      _ => l.t('upcoming'),
    };
  }

  String _emptyRidesMessage(String value) {
    final l = LanguageService.instance;
    return switch (value) {
      'History' => l.t('no_history_rides'),
      'Canceled' => l.t('no_canceled_rides'),
      _ => l.t('no_upcoming_rides'),
    };
  }
}

class _BookingsPayload {
  final Map<String, List<TransportTrip>> history;
  final PricingRules rules;

  const _BookingsPayload({required this.history, required this.rules});
}

class _SegmentedTabs extends StatelessWidget {
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final String Function(String value)? labelFor;

  const _SegmentedTabs({
    required this.value,
    required this.values,
    required this.onChanged,
    this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    AppColors.setDarkMode(dark);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1B1B1B) : const Color(0xFFFFFEFA),
        borderRadius: BorderRadius.circular(14),
        border: dark ? Border.all(color: AppColors.border) : null,
        boxShadow: dark
            ? const []
            : [
                BoxShadow(
                  color: const Color(0x143B2A10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Row(
        children: [
          for (final item in values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        value == item ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labelFor?.call(item) ?? item,
                    style: TextStyle(
                      color: value == item
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final TransportTrip trip;
  final PricingRules rules;
  final VoidCallback onChanged;

  const _BookingCard({
    required this.trip,
    required this.rules,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final canModify = _canModify();
    final canCancel = _canCancel();
    final categoryLabel = trip.vehicleType.isNotEmpty
        ? trip.vehicleType.toUpperCase()
        : '';
    final vehicleName = trip.vehicleClass.isNotEmpty
        ? trip.vehicleClass
        : trip.vehicleType;
    final showActions = trip.status != 'completed' &&
        trip.status != 'cancelled' &&
        trip.status != 'rejected';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (categoryLabel.isNotEmpty) ...[
                        Text(
                          categoryLabel,
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        vehicleName,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _TripStatusBadge(status: trip.status),
              ],
            ),

            const SizedBox(height: 20),

            // Timeline
            _RouteLine(from: trip.pickupLocation, to: trip.destinationName),

            const SizedBox(height: 16),

            // Divider
            Container(height: 1, color: AppColors.border),

            const SizedBox(height: 14),

            // Date & Fare
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l.t('date')} & ${l.t('time')}'.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${trip.departureDate} • ${trip.departureTime}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l.t('fixed').toUpperCase(),
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // Quotes are issued in EUR — the receipt must agree.
                      '${trip.totalPrice.toStringAsFixed(2)} EUR',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Action buttons
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _TripActionButton(
                      label: l.t('modify'),
                      onTap: canModify
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _ModifyBookingScreen(
                                      trip: trip, rules: rules),
                                ),
                              );
                              onChanged();
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TripActionButton(
                      label: l.t('cancel'),
                      danger: true,
                      onTap: canCancel
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _CancelBookingScreen(
                                      trip: trip, rules: rules),
                                ),
                              );
                              onChanged();
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _canModify() {
    return const PricingService().canChangeBooking(
      trip.departureDate,
      trip.departureTime,
      rules.modificationLimitHours,
    );
  }

  bool _canCancel() {
    return const PricingService().canChangeBooking(
      trip.departureDate,
      trip.departureTime,
      rules.cancellationLimitHours,
    );
  }
}

class _RouteLine extends StatelessWidget {
  final String from;
  final String to;

  const _RouteLine({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: 14),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(
              width: 1,
              height: 38,
              child: CustomPaint(painter: _VerticalDashPainter()),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondary, width: 1.5),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.t('pickup').toUpperCase(),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                from,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l.t('destination').toUpperCase(),
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                to,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TripStatusBadge extends StatelessWidget {
  final String status;

  const _TripStatusBadge({required this.status});

  String _labelFor(LanguageService l) {
    return switch (status) {
      'assigned' || 'confirmed' || 'started' || 'arrived' =>
        l.t('status_in_progress').toUpperCase(),
      'completed' => l.t('status_completed').toUpperCase(),
      'cancelled' || 'rejected' => l.t('status_cancelled').toUpperCase(),
      _ => l.t('status_upcoming').toUpperCase(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final Color bg;
    final Color textColor;
    final Color borderColor;

    switch (status) {
      case 'assigned':
      case 'confirmed':
        bg = AppColors.secondary;
        textColor = AppColors.primary;
        borderColor = Colors.transparent;
      case 'completed':
        bg = const Color(0xFF1A2E1A);
        textColor = const Color(0xFF5CDB5C);
        borderColor = const Color(0xFF2E5A2E);
      case 'cancelled':
      case 'rejected':
        bg = const Color(0xFF2A1010);
        textColor = const Color(0xFFFF6B6B);
        borderColor = const Color(0xFF5A2020);
      default:
        bg = AppColors.secondary.withValues(alpha: 0.12);
        textColor = AppColors.secondary;
        borderColor = AppColors.secondary.withValues(alpha: 0.30);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        _labelFor(l),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _TripActionButton extends StatelessWidget {
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  const _TripActionButton({
    required this.label,
    this.danger = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.38 : 1.0,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: danger
                  ? const Color(0xFFFF6B6B).withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: danger
                  ? const Color(0xFFFF6B6B)
                  : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalDashPainter extends CustomPainter {
  const _VerticalDashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    double y = 0;
    const dash = 4.0;
    const gap = 4.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _ModifyBookingScreen extends StatefulWidget {
  final TransportTrip trip;
  final PricingRules rules;

  const _ModifyBookingScreen({required this.trip, required this.rules});

  @override
  State<_ModifyBookingScreen> createState() => _ModifyBookingScreenState();
}

class _ModifyBookingScreenState extends State<_ModifyBookingScreen> {
  late final TextEditingController _pickup;
  late final TextEditingController _destination;
  late DateTime _date;
  late TimeOfDay _time;
  late int _passengers;
  late int _luggage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pickup = TextEditingController(text: widget.trip.pickupLocation);
    _destination = TextEditingController(text: widget.trip.destinationName);
    _date = _parseDate(widget.trip.departureDate) ?? DateTime.now();
    _time = _parseTime(widget.trip.departureTime) ?? TimeOfDay.now();
    _passengers = widget.trip.passengerCount;
    _luggage = widget.trip.luggageCount;
  }

  @override
  void dispose() {
    _pickup.dispose();
    _destination.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = LanguageService.instance;
    final date = DateFormat('yyyy-MM-dd').format(_date);
    final time = _time.format(context);
    final allowed = const PricingService().canChangeBooking(
      date,
      time,
      widget.rules.modificationLimitHours,
    );
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.t(
              'booking_modify_limit',
              args: {'hours': widget.rules.modificationLimitHours},
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await const TripService().updateTrip(widget.trip.id, {
        'pickup_location': _pickup.text.trim(),
        'destination_name': _destination.text.trim(),
        'destination_city': _destination.text.trim(),
        'departure_date': date,
        'departure_time': time,
        'pickup_time': '$date $time',
        'passenger_count': _passengers,
        'luggage_count': _luggage,
      });
      if (!mounted) return;
      // App-scoped messenger survives the pop — success toast shows on the
      // refreshed trips list underneath.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('booking_updated'))),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return LuxuryScaffold(
      title: l.t('modify_booking'),
      subtitle: l.t(
        'modify_booking_subtitle',
        args: {'hours': widget.rules.modificationLimitHours},
      ),
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      // The form is shorter than the viewport, so the default scrollable layout
      // left a large dead gap under the button. Instead the fields scroll and
      // the action is pinned to the bottom of the screen.
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  LuxuryTextField(
                    controller: _pickup,
                    label: l.t('pickup'),
                    hintText: l.t('pickup_hint'),
                    icon: Icons.my_location_rounded,
                  ),
                  const SizedBox(height: 14),
                  LuxuryTextField(
                    controller: _destination,
                    label: l.t('destination'),
                    hintText: l.t('destination'),
                    icon: Icons.location_on_rounded,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerTile(
                          icon: Icons.calendar_month_rounded,
                          label: l.t('date'),
                          value: DateFormat('MMM d, yyyy').format(_date),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PickerTile(
                          icon: Icons.schedule_rounded,
                          label: l.t('time'),
                          value: _time.format(context),
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _StepperRow(
                    icon: Icons.groups_rounded,
                    label: l.t('passengers'),
                    value: _passengers,
                    onChanged: (value) => setState(() => _passengers = value),
                  ),
                  const SizedBox(height: 10),
                  _StepperRow(
                    icon: Icons.luggage_rounded,
                    label: l.t('luggage'),
                    value: _luggage,
                    onChanged: (value) => setState(() => _luggage = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          LuxuryButton(
            text: l.t('save_changes'),
            loading: _busy,
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null) setState(() => _time = value);
  }

  DateTime? _parseDate(String value) {
    try {
      return DateFormat('yyyy-MM-dd').parse(value);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseTime(String value) {
    for (final format in ['h:mm a', 'HH:mm']) {
      try {
        final parsed = DateFormat(format).parse(value);
        return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
      } catch (_) {
        // Try next format.
      }
    }
    return null;
  }
}

class _CancelBookingScreen extends StatefulWidget {
  final TransportTrip trip;
  final PricingRules rules;

  const _CancelBookingScreen({required this.trip, required this.rules});

  @override
  State<_CancelBookingScreen> createState() => _CancelBookingScreenState();
}

class _CancelBookingScreenState extends State<_CancelBookingScreen> {
  bool _busy = false;

  Future<void> _cancel() async {
    final l = LanguageService.instance;
    final allowed = const PricingService().canChangeBooking(
      widget.trip.departureDate,
      widget.trip.departureTime,
      widget.rules.cancellationLimitHours,
    );
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.t(
              'booking_cancel_limit',
              args: {'hours': widget.rules.cancellationLimitHours},
            ),
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await const TripService().cancelBooking(widget.trip.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFF2A1010),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return LuxuryScaffold(
      title: l.t('cancel'),
      subtitle: l.t(
        'modify_booking_subtitle',
        args: {'hours': widget.rules.cancellationLimitHours},
      ),
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LuxuryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.trip.vehicleClass.isEmpty
                      ? widget.trip.vehicleType
                      : widget.trip.vehicleClass,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _RouteLine(
                  from: widget.trip.pickupLocation,
                  to: widget.trip.destinationName,
                ),
                const SizedBox(height: 14),
                BookingInfoRow(
                  label: l.t('departure'),
                  value:
                      '${widget.trip.departureDate} ${widget.trip.departureTime}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LuxuryCard(
            child: Text(
              l.t('booking_cancel_note'),
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
          ),
          const SizedBox(height: 18),
          LuxuryButton(
            text: l.t('confirm_cancellation'),
            loading: _busy,
            onPressed: _cancel,
            variant: LuxuryButtonVariant.outline,
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final waiting = value == LanguageService.instance.t('select');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border:
              AppColors.isDark ? Border.all(color: AppColors.goldBorder) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentText, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          waiting ? AppColors.secondary : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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

class _StepperRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _StepperRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: Icon(Icons.remove_circle_outline_rounded),
            color: AppColors.textSecondary,
          ),
          Text(
            '$value',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: Icon(Icons.add_circle_outline_rounded),
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _FavoritesTab extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onOpenNotifications;
  final int unreadCount;

  const _FavoritesTab({
    this.onNavigateToProfile,
    this.onOpenNotifications,
    this.unreadCount = 0,
  });

  @override
  State<_FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<_FavoritesTab> {
  late Future<List<FavoriteLocation>> _future;

  @override
  void initState() {
    super.initState();
    _future = const FavoriteService().listFavorites();
  }

  void _reload() {
    setState(() {
      _future = const FavoriteService().listFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final isAuth = AuthService.instance.isAuthenticated;

    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: FutureBuilder<List<FavoriteLocation>>(
          future: _future,
          builder: (context, snapshot) {
            final items = snapshot.data ?? FavoriteService.defaults;
            return Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 110),
                  children: [
                    // Shared top bar (the old header's hamburger did nothing).
                    ClientTopBar(
                      unreadCount: widget.unreadCount,
                      onProfileTap: widget.onNavigateToProfile,
                      onNotificationTap: widget.onOpenNotifications,
                      horizontalPadding: 0, // list already gutters by 22
                    ),

                    // Hero title
                    const SizedBox(height: 20),
                    Text(
                      l.t('favorites'),
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAuth
                          ? l.t('saved_hero_subtitle')
                          : l.t('login_required_favorites'),
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Favorites list
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        snapshot.data == null)
                      // Skeletons instead of a spinner, matching Trips/Fleet.
                      const SkeletonCardList(
                        count: 3,
                        cardHeight: 92,
                        padding: EdgeInsets.zero,
                      )
                    else
                      for (final item in items)
                        _FavoriteTile(
                          item: item,
                          onDelete: isAuth
                              ? () async {
                                  await const FavoriteService()
                                      .deleteFavorite(item.id);
                                  _reload();
                                }
                              : null,
                        ),

                    // â”€â”€ Add button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    if (isAuth) ...[
                      const SizedBox(height: 20),
                      _AddLocationButton(
                        label: l.t('add_new_location'),
                        onTap: () => _showAddFavorite(context),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAddFavorite(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFavoriteSheet(onSaved: _reload),
    );
  }
}

/// A saved place in the list. Kept intentionally lean — tapping it opens
/// [_FavoriteDetailSheet], where the address, album and actions live. The list
/// only hints at the album with a photo-count badge.
class _FavoriteTile extends StatefulWidget {
  final FavoriteLocation item;
  final VoidCallback? onDelete;

  const _FavoriteTile({required this.item, this.onDelete});

  @override
  State<_FavoriteTile> createState() => _FavoriteTileState();
}

class _FavoriteTileState extends State<_FavoriteTile> {
  static const _memories = FavoriteMemoriesService();
  int _photoCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final count = await _memories.countFor(widget.item.id);
    if (mounted) setState(() => _photoCount = count);
  }

  void _openDetail() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FavoriteDetailSheet(
        item: widget.item,
        onDelete: widget.onDelete,
      ),
      // The album may have grown or shrunk while the sheet was open.
    ).then((_) => _refreshCount());
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return InkWell(
      onTap: _openDetail,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.softBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                favoriteTypeIcon(item.type),
                color: AppColors.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                      if (_photoCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_camera_back_outlined,
                                  size: 11, color: AppColors.secondary),
                              const SizedBox(width: 3),
                              Text(
                                '$_photoCount',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

IconData favoriteTypeIcon(String type) {
  return switch (type) {
    'home' => Icons.home_outlined,
    'work' => Icons.business_center_outlined,
    'airport' => Icons.flight_takeoff_rounded,
    'hotel' => Icons.king_bed_outlined,
    _ => Icons.location_on_outlined,
  };
}

// ─── Favourite detail sheet (info + photo album) ──────────────────────────────

class _FavoriteDetailSheet extends StatefulWidget {
  final FavoriteLocation item;
  final VoidCallback? onDelete;

  const _FavoriteDetailSheet({required this.item, this.onDelete});

  @override
  State<_FavoriteDetailSheet> createState() => _FavoriteDetailSheetState();
}

class _FavoriteDetailSheetState extends State<_FavoriteDetailSheet> {
  static const _memories = FavoriteMemoriesService();
  List<String> _photos = const [];
  bool _loading = true;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final photos = await _memories.photosFor(widget.item.id);
    if (mounted) {
      setState(() {
        _photos = photos;
        _loading = false;
      });
    }
  }

  Future<void> _addPhoto(ImageSource source) async {
    // The platform picker is a single shared resource: a second tap while it is
    // opening throws PlatformException('already_active').
    if (_picking) return;
    _picking = true;
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return;
      final updated = await _memories.addPhoto(widget.item.id, file.path);
      if (mounted) setState(() => _photos = updated);
    } on PlatformException catch (error) {
      if (error.code != 'already_active' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LanguageService.instance.t('photo_failed'))),
        );
      }
    } finally {
      _picking = false;
    }
  }

  void _pickSource() {
    final l = LanguageService.instance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: AppColors.secondary),
              title: Text(l.t('choose_from_gallery'),
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _addPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: AppColors.secondary),
              title: Text(l.t('take_photo'),
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _addPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemovePhoto(String path) async {
    final l = LanguageService.instance;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.t('delete_photo'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Text(l.t('delete_photo_confirm'),
            style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.t('cancel'),
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child:
                Text(l.t('delete'), style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final updated = await _memories.removePhoto(widget.item.id, path);
    if (mounted) setState(() => _photos = updated);
  }

  Future<void> _confirmDeleteFavorite() async {
    final l = LanguageService.instance;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.t('delete_location'),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
        content: Text(
          l.t('delete_location_photos_confirm',
              args: {'name': widget.item.label}),
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.t('cancel'),
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child:
                Text(l.t('delete'), style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    // Drop the album with the favourite so orphaned photos never linger.
    await _memories.clearFor(widget.item.id);
    widget.onDelete?.call();
    if (mounted) Navigator.of(context).pop();
  }

  void _openFullScreen(String path) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _PhotoViewerScreen(path: path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    final l = LanguageService.instance;
    final item = widget.item;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppColors.softBorder),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(favoriteTypeIcon(item.type),
                            color: AppColors.secondary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _favoriteTypeName(item.type),
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.softBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.place_outlined,
                            color: AppColors.textMuted, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.address,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.t('memories'),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickSource,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color:
                                    AppColors.secondary.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined,
                                  size: 14, color: AppColors.secondary),
                              const SizedBox(width: 6),
                              Text(
                                l.t('add_photo'),
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const SkeletonPulse(
                      child: SkeletonBox(height: 120, radius: 14),
                    )
                  else if (_photos.isEmpty)
                    _EmptyAlbum(onAdd: _pickSource)
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _photos.length,
                      itemBuilder: (_, i) {
                        final path = _photos[i];
                        return GestureDetector(
                          onTap: () => _openFullScreen(path),
                          onLongPress: () => _confirmRemovePhoto(path),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.surfaceElevated,
                                    child: Icon(Icons.broken_image_outlined,
                                        color: AppColors.textMuted, size: 20),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _confirmRemovePhoto(path),
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.55),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded,
                                          size: 13, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 28),
                  if (widget.onDelete != null)
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _confirmDeleteFavorite,
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 18),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(
                              color: AppColors.danger.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        label: Text(
                          l.t('delete_location'),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
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

  String _favoriteTypeName(String type) {
    final l = LanguageService.instance;
    return switch (type) {
      'home' => l.t('home'),
      'work' => l.t('work'),
      'airport' => l.t('airport'),
      _ => l.t('custom'),
    }
        .toUpperCase();
  }
}

class _EmptyAlbum extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyAlbum({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.softBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.photo_camera_back_outlined,
                  color: AppColors.secondary, size: 25),
            ),
            const SizedBox(height: 14),
            Text(
              l.t('no_memories_yet'),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              l.t('add_first_memory'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinch/pan viewer for a single memory.
class _PhotoViewerScreen extends StatelessWidget {
  final String path;

  const _PhotoViewerScreen({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48),
          ),
        ),
      ),
    );
  }
}

class _AddLocationButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddLocationButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: AppColors.secondary.withValues(alpha: 0.40),
          radius: 16,
        ),
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_location_alt_outlined,
                  color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  // Fixed dash geometry — no caller has ever needed to vary these.
  static const strokeWidth = 1.0;
  static const dashWidth = 6.0;
  static const dashSpace = 5.0;

  const _DashedBorderPainter({
    required this.color,
    this.radius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(
            strokeWidth / 2, strokeWidth / 2,
            size.width - strokeWidth, size.height - strokeWidth),
        Radius.circular(radius),
      ));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final len = draw ? dashWidth : dashSpace;
        if (draw) {
          dashPath.addPath(
              metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

class _AddFavoriteSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const _AddFavoriteSheet({required this.onSaved});

  @override
  State<_AddFavoriteSheet> createState() => _AddFavoriteSheetState();
}

class _AddFavoriteSheetState extends State<_AddFavoriteSheet> {
  final _label = TextEditingController();
  final _address = TextEditingController();
  String _type = 'custom';
  bool _busy = false;

  // ── Places autocomplete (same pipeline as the booking search screen) ──────
  static const _places = PlacesService(kMapsApiKey);
  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _suppressLookup = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _label.dispose();
    _address.dispose();
    super.dispose();
  }

  /// 400 ms debounce so typing an address is one request, not one per keystroke.
  void _onAddressChanged(String value) {
    if (_suppressLookup) {
      _suppressLookup = false;
      return;
    }
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _places.autocomplete(value);
      if (mounted) setState(() => _suggestions = results);
    });
  }

  void _pickSuggestion(PlaceSuggestion suggestion) {
    // Setting .text refires onChanged; skip that one so the list doesn't reopen.
    _suppressLookup = true;
    _address.text = suggestion.description;
    FocusScope.of(context).unfocus();
    setState(() => _suggestions = []);
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty || _address.text.trim().isEmpty) return;
    setState(() => _busy = true);
    await const FavoriteService().addFavorite(
      label: _label.text.trim(),
      address: _address.text.trim(),
      type: _type,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    final l = LanguageService.instance;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(22, 20, 22, bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            l.t('add_new_location'),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.t('saved_hero_subtitle'),
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _PremiumSheetField(
            controller: _label,
            label: l.t('location_name'),
            hint: l.t('favorite_label_hint'),
            icon: Icons.label_outline_rounded,
          ),
          const SizedBox(height: 14),
          // Address is resolved through Google Places rather than typed free-
          // hand, so saved favourites match real, geocodable locations.
          _PremiumSheetField(
            controller: _address,
            label: l.t('address'),
            hint: l.t('search_address'),
            icon: Icons.location_on_outlined,
            onChanged: _onAddressChanged,
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 190),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.softBorder),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _suggestions.length,
                itemBuilder: (_, i) {
                  final s = _suggestions[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.place_outlined,
                        color: AppColors.secondary, size: 19),
                    title: Text(
                      s.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 13),
                    ),
                    onTap: () => _pickSuggestion(s),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          _SegmentedTabs(
            value: _type,
            values: const ['home', 'work', 'airport', 'custom'],
            labelFor: _favoriteTypeLabel,
            onChanged: (value) => setState(() => _type = value),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: _busy ? null : _save,
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PremiumProfilePalette.gold,
                borderRadius: BorderRadius.circular(999),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: PremiumProfilePalette.goldDeep,
                          strokeWidth: 2.5),
                    )
                  : Text(
                      l.t('save_location').toUpperCase(),
                      style: const TextStyle(
                        color: PremiumProfilePalette.goldDeep,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _favoriteTypeLabel(String value) {
    final l = LanguageService.instance;
    return switch (value) {
      'home' => l.t('home'),
      'work' => l.t('work'),
      'airport' => l.t('airport'),
      _ => l.t('custom'),
    };
  }
}

class _PremiumSheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final ValueChanged<String>? onChanged;

  const _PremiumSheetField({
    required this.controller,
    required this.label,
    this.onChanged,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.softBorder),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon:
                  Icon(icon, color: AppColors.secondary, size: 20),
              hintText: hint,
              hintStyle: TextStyle(
                  color: AppColors.textHint, fontSize: 14),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// _AlertsTab replaced by NotificationsScreen
// See lib/features/notifications/notifications_screen.dart


/// The client's standing as a physical membership card — dark lacquer,
/// gold detailing, tier front and centre. Tapping opens the full Rewards
/// screen. Data is best-effort: renders gracefully while loading.
class _MembershipCard extends StatelessWidget {
  final String memberName;
  final Map<String, dynamic>? rewards;
  final VoidCallback onTap;

  const _MembershipCard({
    required this.memberName,
    required this.rewards,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC8A96B);
    final tier = rewards?['tier']?.toString() ?? '—';
    final completed = (rewards?['completed_trips'] as num? ?? 0).toInt();
    final points = (rewards?['points'] as num? ?? completed * 10).toInt();
    final nextTier = rewards?['next_tier']?.toString() ?? '';
    final threshold = (rewards?['next_tier_threshold'] as num? ?? 0).toInt();
    // Both sides in points — the threshold is a points value, so comparing it
    // against the trip count understated progress by a factor of 10.
    final progress =
        threshold > 0 ? (points / threshold).clamp(0.0, 1.0) : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF191510), Color(0xFF0C0A07)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gold.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CARTHAGE PRIVILÈGE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.6,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: gold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    tier.toUpperCase(),
                    style: const TextStyle(
                      color: gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$points',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'POINTS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.50),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.workspace_premium_rounded,
                    color: gold.withValues(alpha: 0.85), size: 26),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                color: gold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    memberName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
                Text(
                  nextTier.isEmpty || threshold <= 0
                      ? 'TOP TIER'
                      // 10 points per ride, so convert the points gap back to
                      // rides (rounded up) for a number the client can act on.
                      : '${(((threshold - points).clamp(0, threshold)) / 10).ceil()} RIDES TO ${nextTier.toUpperCase()}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class _RewardsScreen extends StatefulWidget {
  const _RewardsScreen();

  @override
  State<_RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<_RewardsScreen> {
  static const _service = RewardService();
  bool _loading = true;
  int _completed = 0;
  int _points = 0;
  String _tier = 'Bronze';
  String _nextTier = 'Silver';
  int _nextThreshold = 30;
  Map<String, dynamic>? _tierPromo;
  List<Map<String, dynamic>> _promos = const [];
  String _referralCode = '';
  double _referralCredits = 0;
  double _referralReward = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.getRewardsMe();
      if (!mounted) return;
      setState(() {
        _completed = (data['completed_trips'] as num? ?? 0).toInt();
        _points = (data['points'] as num? ?? 0).toInt();
        _tier = data['tier']?.toString() ?? 'Bronze';
        _nextTier = data['next_tier']?.toString() ?? '';
        _nextThreshold = (data['next_tier_threshold'] as num? ?? 0).toInt();
        _tierPromo = (data['tier_promo'] as Map?)?.cast<String, dynamic>();
        _promos = (data['promo_codes'] as List? ?? const [])
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _referralCode = data['referral_code']?.toString() ?? '';
        _referralCredits =
            (data['referral_credits'] as num? ?? 0).toDouble();
        _referralReward = (data['referral_reward'] as num? ?? 5).toDouble();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copy(String value) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LanguageService.instance.t('code_copied')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    // Progress is measured in POINTS against the points threshold. (It used to
    // compare completed *trips* to a points threshold, understating progress.)
    final toNext = (_nextThreshold - _points).clamp(0, _nextThreshold);
    final tierProgress = _nextThreshold > 0
        ? (_points / _nextThreshold).clamp(0.0, 1.0).toDouble()
        : 1.0;
    // The user's own tier code is featured separately, so keep it out of the
    // generic list below.
    final otherPromos = _promos
        .where((p) => p['code'] != _tierPromo?['code'])
        .toList();

    return LuxuryScaffold(
      title: l.t('rewards'),
      subtitle: l.t('rewards_subtitle'),
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _RewardsHero(),
                const SizedBox(height: 18),
                _TierSummaryCard(
                  tier: _tier,
                  completed: _completed,
                  nextTier: _nextTier,
                  toNext: toNext,
                  progress: tierProgress,
                ),
                const SizedBox(height: 22),
                // ── Featured: this member's tier code ──────────────────
                if (_tierPromo != null) ...[
                  _TierPromoCard(
                    promo: _tierPromo!,
                    tier: _tier,
                    onCopy: () => _copy(_tierPromo!['code']?.toString() ?? ''),
                  ),
                  const SizedBox(height: 18),
                ],
                // ── Referral ───────────────────────────────────────────
                _ReferralCard(
                  code: _referralCode,
                  credits: _referralCredits,
                  reward: _referralReward,
                  onCopy: () => _copy(_referralCode),
                ),
                const SizedBox(height: 22),
                Text(
                  l.t('available_promo_codes'),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                if (otherPromos.isEmpty)
                  Text(
                    'No other active promotions at this time.',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13),
                  )
                else
                  for (final promo in otherPromos) ...[
                    _PromoRewardCard(
                      code: promo['code']?.toString() ?? '',
                      rides: _usesLabel(promo),
                      discount: (promo['discount_type'] == 'percentage')
                          ? '${(promo['value'] as num?)?.toStringAsFixed(0) ?? '0'}% Discount'
                          : '${(promo['value'] as num?)?.toStringAsFixed(0) ?? '0'} EUR off',
                      isWelcome: promo['welcome'] == true,
                      onCopy: () => _copy(promo['code']?.toString() ?? ''),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
    );
  }
}

/// "2 of 3 uses remaining", or unlimited when the limit is 0.
String _usesLabel(Map<String, dynamic> promo) {
  final l = LanguageService.instance;
  final limit = (promo['usage_limit'] as num? ?? 0).toInt();
  final used = (promo['usage_count'] as num? ?? 0).toInt();
  if (limit <= 0) return l.t('unlimited_uses');
  final left = (limit - used).clamp(0, limit);
  if (left == 0) return l.t('code_fully_used');
  return l.t('uses_remaining', args: {'used': left, 'total': limit});
}

/// The member's personal tier code — the headline reward on this screen.
class _TierPromoCard extends StatelessWidget {
  final Map<String, dynamic> promo;
  final String tier;
  final VoidCallback onCopy;

  const _TierPromoCard({
    required this.promo,
    required this.tier,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final code = promo['code']?.toString() ?? '';
    final value = (promo['value'] as num?)?.toStringAsFixed(0) ?? '0';
    final expiry = promo['expiry_date']?.toString();
    final limit = (promo['usage_limit'] as num? ?? 0).toInt();
    final used = (promo['usage_count'] as num? ?? 0).toInt();
    final spent = limit > 0 && used >= limit;

    String? expiryLabel;
    if (expiry != null && expiry.isNotEmpty) {
      final parsed = DateTime.tryParse(expiry);
      if (parsed != null) {
        expiryLabel = l.t('expires_on',
            args: {'date': DateFormat('d MMM yyyy').format(parsed)});
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF191510), Color(0xFF0C0A07)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${tier.toUpperCase()} · ${l.t('your_promo_code')}',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              Text(
                '$value% OFF',
                style: const TextStyle(
                  color: Color(0xFFE0C68A),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      color: Color(0xFFFFFCF3),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: spent ? null : onCopy,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: spent
                        ? AppColors.secondary.withValues(alpha: 0.25)
                        : AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l.t('copy_code'),
                    style: const TextStyle(
                      color: Color(0xFF221A08),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                spent ? Icons.hourglass_bottom_rounded : Icons.confirmation_num_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _usesLabel(promo),
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ),
              if (expiryLabel != null)
                Text(
                  expiryLabel,
                  style:
                      TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Share-your-code panel with the running referral credit balance.
class _ReferralCard extends StatelessWidget {
  final String code;
  final double credits;
  final double reward;
  final VoidCallback onCopy;

  const _ReferralCard({
    required this.code,
    required this.credits,
    required this.reward,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard_rounded,
                  color: AppColors.secondary, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.t('referral_title'),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (credits > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${credits.toStringAsFixed(2)} EUR',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.t('referral_desc'),
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.softBorder),
                  ),
                  child: Text(
                    code.isEmpty ? '—' : code,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: code.isEmpty ? null : onCopy,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.share_rounded,
                          size: 14, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Text(
                        l.t('share'),
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierSummaryCard extends StatelessWidget {
  final String tier;
  final int completed;
  final String nextTier;
  final int toNext;
  final double progress;

  const _TierSummaryCard({
    required this.tier,
    required this.completed,
    required this.nextTier,
    required this.toNext,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      padding: const EdgeInsets.all(16),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Icon(Icons.workspace_premium_rounded,
                    color: AppColors.secondary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT TIER',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tier.toUpperCase()} MEMBER',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$completed',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'rides',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.isDark
                  ? const Color(0xFF070707)
                  : const Color(0xFFE8DDC6),
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // `toNext` is a points gap; show it as rides (10 pts each).
            '${(toNext / 10).ceil()} more rides to reach ${nextTier.toUpperCase()}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsHero extends StatelessWidget {
  const _RewardsHero();

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return Container(
      height: 112,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.isDark
              ? const [Color(0xFFA86605), Color(0xFF2A1702)]
              : const [Color(0xFFFFF4D4), Color(0xFFE5B84F)],
        ),
        border:
            AppColors.isDark ? Border.all(color: AppColors.goldBorder) : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l.t('your_rewards'),
                  style: TextStyle(
                    color: AppColors.isDark
                        ? AppColors.textPrimary
                        : const Color(0xFF21180B),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  l.t('rewards_subtitle'),
                  style: TextStyle(
                    color: AppColors.isDark
                        ? AppColors.textSecondary
                        : const Color(0xFF6F5820),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [AppColors.secondaryLight, AppColors.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Icon(
              Icons.card_giftcard_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoRewardCard extends StatelessWidget {
  final String code;
  final String rides;
  final String discount;
  final bool isWelcome;
  final VoidCallback? onCopy;

  const _PromoRewardCard({
    required this.code,
    required this.rides,
    required this.discount,
    this.isWelcome = false,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return LuxuryCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      radius: 14,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        code,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isWelcome) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          l.t('welcome_offer').toUpperCase(),
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  rides,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            discount,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onCopy,
            icon: Icon(Icons.copy_rounded, color: AppColors.textHint, size: 17),
            tooltip: l.t('copy_code'),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  final VoidCallback onOpenNotifications;
  final int unreadCount;

  const _ProfileTab({
    required this.onOpenNotifications,
    required this.unreadCount,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late UserModel _user;
  bool _refreshedProfile = false;
  bool _pickingAvatar = false;

  // Membership data — surfaced on the profile so the client always sees
  // their standing (was previously buried behind the Rewards row).
  Map<String, dynamic>? _rewards;

  @override
  void initState() {
    super.initState();
    _user = AuthService.instance.currentUser ?? AuthService.instance.demoUser;
    if (AuthService.instance.isAuthenticated) {
      const RewardService().getRewardsMe().then((data) {
        if (mounted) setState(() => _rewards = data);
      }).catchError((_) {});
    }
  }

  Future<void> _editProfile() async {
    if (!AuthService.instance.isAuthenticated) {
      _goLogin();
      return;
    }
    final updated = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user)),
    );
    if (updated != null && mounted) setState(() => _user = updated);
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    _goLogin();
  }

  void _goLogin() {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_refreshedProfile || !AuthService.instance.isAuthenticated) return;
    _refreshedProfile = true;
    AuthService.instance.refreshProfile().then((updated) {
      if (mounted) setState(() => _user = updated);
    }).catchError((_) {});
  }

  Future<void> _pickAvatar() async {
    if (!AuthService.instance.isAuthenticated) {
      _goLogin();
      return;
    }
    // Same single-shared-resource guard as the favourites photo picker: a
    // double tap would otherwise throw PlatformException('already_active').
    if (_pickingAvatar) return;
    _pickingAvatar = true;
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (file == null) return;
      final updated = await AuthService.instance.uploadAvatar(file);
      if (mounted) setState(() => _user = updated);
    } on PlatformException catch (error) {
      if (error.code != 'already_active' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LanguageService.instance.t('photo_failed'))),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      _pickingAvatar = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final isGuest = AuthService.instance.isGuest;
    return PremiumProfileBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 110),
          children: [
            ClientTopBar(
              unreadCount: widget.unreadCount,
              onNotificationTap: widget.onOpenNotifications,
              // Already on Profile, so the avatar is inert here.
              onProfileTap: null,
              horizontalPadding: 0, // list already gutters by 24
            ),
            const SizedBox(height: 42),
            Center(
              child: PremiumProfileAvatar(
                user: _user,
                onEditTap: isGuest ? _goLogin : _pickAvatar,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              isGuest ? l.t('guest_browsing') : _user.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PremiumProfilePalette.text(context),
                fontSize: 36,
                fontWeight: FontWeight.w700,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: PremiumProfilePalette.gold.withValues(alpha: 0.34),
                  ),
                ),
                child: Text(
                  premiumProfileRoleBadge(
                    _user,
                    loyaltyTier: _rewards?['tier']?.toString(),
                  ).toUpperCase(),
                  style: const TextStyle(
                    color: PremiumProfilePalette.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isGuest ? l.t('login_to_reserve') : _user.email,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PremiumProfilePalette.subtitle(context),
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 40),
            PremiumProfilePrimaryButton(
              text: isGuest ? l.t('login_or_register') : l.t('edit_profile'),
              onTap: isGuest ? _goLogin : _editProfile,
            ),
            // ── Membership card: tier + points, front and centre ────────
            if (!isGuest) ...[
              const SizedBox(height: 28),
              _MembershipCard(
                memberName: _user.name,
                rewards: _rewards,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _RewardsScreen()),
                ),
              ),
            ],
            // Bookings, Favorites and AVA are all first-class nav destinations
            // now, so their duplicate shortcuts were removed from here.
            const SizedBox(height: 32),
            if (!isGuest)
              PremiumProfileActionCard(
                icon: Icons.workspace_premium_outlined,
                title: l.t('rewards'),
                subtitle: l.t('rewards_subtitle'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _RewardsScreen()),
                ),
              ),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeService.instance.mode,
              builder: (_, mode, __) => PremiumProfileActionCard(
                icon: Icons.tune_rounded,
                title: l.t('preferences'),
                subtitle:
                    '${l.languageName(l.current)} - ${mode == ThemeMode.dark ? l.t('dark_mode') : l.t('light_mode')}',
                onTap: () => _openSettings(context),
              ),
            ),
            PremiumProfileActionCard(
              icon: Icons.headset_mic_outlined,
              title: l.t('support'),
              subtitle: l.t('support_desc'),
              onTap: _showSupport,
            ),
            const SizedBox(height: 24),
            Center(
              child: PremiumProfileGhostButton(
                text: isGuest ? l.t('login') : l.t('logout'),
                icon: isGuest ? Icons.login_rounded : Icons.logout_rounded,
                onTap: isGuest ? _goLogin : _logout,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _SettingsScreen(),
      ),
    );
  }

  void _showSupport() {
    final l = LanguageService.instance;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LuxuryHeader(
                  title: l.t('support'), subtitle: l.t('support_available')),
              SizedBox(height: 14),
              _SupportLine(
                icon: Icons.phone_outlined,
                title: l.t('call_support'),
                value: '+216 71 000 000',
              ),
              _SupportLine(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'WhatsApp',
                value: l.t('instant_response'),
              ),
              _SupportLine(
                icon: Icons.email_outlined,
                title: 'Email',
                value: 'support@carthagetransfer.com',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: LanguageService.instance.language,
      builder: (context, _, __) {
        final l = LanguageService.instance;
        final language = l.languageName(l.current);

        return LuxuryScaffold(
          title: l.t('settings'),
          subtitle: l.t('display_preferences'),
          leading: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LuxurySectionHeader(title: l.t('language')),
              const SizedBox(height: 10),
              _SegmentedTabs(
                value: language,
                values: [
                  l.languageName(AppLanguage.english),
                  l.languageName(AppLanguage.french),
                ],
                onChanged: (value) => LanguageService.instance
                    .setLanguage(l.languageFromName(value)),
              ),
              const SizedBox(height: 18),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeService.instance.mode,
                builder: (_, mode, __) {
                  final dark = mode == ThemeMode.dark;
                  return LuxuryCard(
                    child: Row(
                      children: [
                        Icon(
                          dark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dark ? l.t('dark_mode') : l.t('light_mode'),
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                dark
                                    ? l.t('dark_mode_desc')
                                    : l.t('light_mode_desc'),
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: dark,
                          activeThumbColor: AppColors.secondary,
                          activeTrackColor:
                              AppColors.secondary.withValues(alpha: 0.4),
                          inactiveThumbColor: AppColors.secondaryDark,
                          inactiveTrackColor:
                              AppColors.secondary.withValues(alpha: 0.18),
                          onChanged: ThemeService.instance.setDark,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SupportLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SupportLine({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
                Text(value, style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
