import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/favorite_location.dart';
import '../../core/models/transport_trip.dart';
import '../../core/models/user_model.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/favorite_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/pricing_service.dart';
import '../../core/services/trip_service.dart';
import '../../data/fleet_data.dart';
import '../../data/home_data.dart';
import '../../models/booking_data.dart';
import '../../models/fleet_item.dart';
import '../../models/vehicle.dart';
import '../../shared/widgets/common/luxury_components.dart';
import '../../shared/widgets/client/premium_client_components.dart';
import '../../shared/widgets/client/premium_profile_components.dart';
import '../../widgets/common/fallback_network_image.dart';
import '../../features/notifications/notifications_screen.dart';
import '../booking_fleet_screen.dart';
import '../booking_search_screen.dart';
import '../edit_profile_screen.dart';
import '../vehicles_screen.dart';

const _homeLightCardColor = Color(0xFFFBF1E8);
const _homeLightSurfaceColor = Color(0xFFFFFEFA);
const _homeLightBorderColor = Color(0xFFF0E4D8);

bool _isLightMode(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

Color _homePanelColor(BuildContext context) =>
    _isLightMode(context) ? _homeLightCardColor : AppColors.surface;

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

class _ClientShellState extends State<ClientShell> {
  late int _index;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4).toInt();
  }

  void _startBooking(BookingData data) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingFleetScreen(data: data)),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
        hasUnread: _unreadCount > 0,
        onStartBooking: _startBooking,
        onOpenVehicles: () => _push(const VehiclesScreen()),
        onOpenAlerts: () => setState(() => _index = 3),
      ),
      _BookingsTab(
        onNavigateToAlerts: () => setState(() => _index = 3),
        onNavigateToProfile: () => setState(() => _index = 4),
      ),
      _FavoritesTab(
        onNavigateToProfile: () => setState(() => _index = 4),
      ),
      NotificationsScreen(
        onUnreadCountChanged: (count) {
          if (count != _unreadCount) setState(() => _unreadCount = count);
        },
        onNavigateToProfile: () => setState(() => _index = 4),
      ),
      _ProfileTab(
        onOpenBookings: () => setState(() => _index = 1),
        onOpenFavorites: () => setState(() => _index = 2),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: LuxuryBackdrop(child: IndexedStack(index: _index, children: tabs)),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: (value) => setState(() => _index = value),
        badged: _unreadCount > 0 ? const {3} : const {},
      ),
    );
  }
}

class _ClientHomeTab extends StatelessWidget {
  final bool hasUnread;
  final ValueChanged<BookingData> onStartBooking;
  final VoidCallback onOpenVehicles;
  final VoidCallback onOpenAlerts;

  const _ClientHomeTab({
    required this.hasUnread,
    required this.onStartBooking,
    required this.onOpenVehicles,
    required this.onOpenAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isGuest = AuthService.instance.isGuest;
    final firstName =
        isGuest ? 'Guest' : (user?.name.split(' ').first ?? '').trim();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : (hour < 17 ? 'Good Afternoon' : 'Good Evening');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeHero(
              firstName: firstName,
              greeting: greeting,
              hasUnread: hasUnread,
              onOpenAlerts: onOpenAlerts,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isGuest) ...[
                    _GuestNotice(onLogin: () => _goLogin(context)),
                    const SizedBox(height: 14),
                  ],
                  _WhereToCard(
                    onBookNow: () => _openBooking(context),
                  ),
                  const SizedBox(height: 28),
                  _PremiumFleetSection(onViewAll: onOpenVehicles),
                  const SizedBox(height: 28),
                  const _FavoritePlacesSection(),
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

class _HomeHero extends StatelessWidget {
  final String firstName;
  final String greeting;
  final bool hasUnread;
  final VoidCallback onOpenAlerts;

  const _HomeHero({
    required this.firstName,
    required this.greeting,
    required this.hasUnread,
    required this.onOpenAlerts,
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: onOpenAlerts,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFC8A96B), width: 1.5),
                            ),
                            child: ClipOval(
                              child: AuthService
                                          .instance.currentUser?.avatarUrl !=
                                      null
                                  ? FallbackNetworkImage(
                                      url: AuthService
                                          .instance.currentUser!.avatarUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: const Color(0xFF101010),
                                      child: const Icon(Icons.person_rounded,
                                          color: Color(0xFFC8A96B), size: 22),
                                    ),
                            ),
                          ),
                          if (hasUnread)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Welcome, $firstName',
                        style: const TextStyle(
                          color: Color(0xFFC8A96B),
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Icon(Icons.menu_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ],
                ),
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
                const Text(
                  'EXPERIENCE EXCELLENCE',
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
                    fontWeight: FontWeight.w900,
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
                    'Your destination',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Where to?',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900),
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
                'Book Now',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
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

class _PremiumFleetSection extends StatelessWidget {
  final VoidCallback onViewAll;

  const _PremiumFleetSection({required this.onViewAll});

  @override
  Widget build(BuildContext context) {
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
                    'Premium Fleet',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    'Curated for executive comfort',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onViewAll,
              child: Text(
                'View All',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: HomeData.vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final vehicle = HomeData.vehicles[index];
              return _HomeFleetCard(vehicle: vehicle, onTap: onViewAll);
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
    final light = _isLightMode(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 178,
        decoration: BoxDecoration(
          color: light ? _homeSurfaceColor(context) : AppColors.surface,
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
                height: 120,
                width: double.infinity,
                color: Colors.white,
                child: vehicle.image.startsWith('assets')
                    ? Image.asset(
                        vehicle.image,
                        fit: BoxFit.contain,
                      )
                    : FallbackNetworkImage(
                        url: vehicle.image,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    Text(
                      '\$${vehicle.price}',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'per trip',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.groups_rounded,
                            color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 3),
                        Text('${vehicle.seatCount}',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                        const SizedBox(width: 10),
                        Icon(Icons.luggage_rounded,
                            color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 3),
                        Text('${vehicle.bags}',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
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

class _FavoritePlacesSection extends StatefulWidget {
  const _FavoritePlacesSection();

  @override
  State<_FavoritePlacesSection> createState() => _FavoritePlacesSectionState();
}

class _FavoritePlacesSectionState extends State<_FavoritePlacesSection> {
  List<FavoriteLocation> _items = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await const FavoriteService().listFavorites();
      if (mounted) {
        setState(() {
          _items = items.isEmpty ? FavoriteService.defaults : items;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _items = FavoriteService.defaults;
          _loaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Favorite Places',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 14),
        for (final item in _items) _FavoritePlaceTile(item: item),
      ],
    );
  }
}

class _FavoritePlaceTile extends StatelessWidget {
  final FavoriteLocation item;

  const _FavoritePlaceTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final light = _isLightMode(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: light ? _homePanelColor(context) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _homeBorderColor(context)),
        boxShadow: light
            ? [
                BoxShadow(
                  color: const Color(0x0F3B2A10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: light
                  ? Colors.white
                  : AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border:
                  light ? Border.all(color: _homeBorderColor(context)) : null,
            ),
            child: Icon(_iconForType(item.type),
                color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(
                  item.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'home' => Icons.home_outlined,
      'work' => Icons.business_center_outlined,
      'airport' => Icons.flight_takeoff_rounded,
      _ => Icons.location_on_outlined,
    };
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
                      fontWeight: FontWeight.w900,
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
                  fontWeight: FontWeight.w900,
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
                          fontWeight: FontWeight.w900,
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
                                fontSize: 18, fontWeight: FontWeight.w900),
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
                            fontWeight: FontWeight.w900,
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

class _FavoritesScreen extends StatelessWidget {
  const _FavoritesScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LuxuryBackdrop(child: const _FavoritesTab()),
    );
  }
}

// â”€â”€â”€ Floating Bottom Navigation Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final Set<int> badged;

  const _BottomNav({
    required this.index,
    required this.onChanged,
    this.badged = const {},
  });

  @override
  Widget build(BuildContext context) {
    return PremiumClientNav(
      index: index,
      onChanged: onChanged,
      badged: badged,
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 22),
    );
  }
}

class _BookingsTab extends StatefulWidget {
  final VoidCallback? onNavigateToAlerts;
  final VoidCallback? onNavigateToProfile;

  const _BookingsTab({this.onNavigateToAlerts, this.onNavigateToProfile});

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  String _filter = 'Upcoming';
  late Future<_BookingsPayload> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
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

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final user = AuthService.instance.currentUser;

    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.secondary,
          backgroundColor: AppColors.surfaceElevated,
          onRefresh: () async => _reload(),
          child: FutureBuilder<_BookingsPayload>(
            future: _future,
            builder: (context, snapshot) {
              final payload = snapshot.data;
              final upcoming = payload?.history['upcoming'] ?? const [];
              final past = payload?.history['past'] ?? const [];
              final cancelled =
                  past.where((t) => t.status == 'cancelled').toList();
              final activeList = switch (_filter) {
                'History' => past,
                'Canceled' => cancelled,
                _ => upcoming,
              };

              return ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 110),
                children: [
                  // â”€â”€ Top bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onNavigateToProfile,
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: ClipOval(
                              child: user?.avatarUrl == null ||
                                      (user?.avatarUrl?.isEmpty ?? true)
                                  ? Container(
                                      color: AppColors.surfaceElevated,
                                      alignment: Alignment.center,
                                      child: Icon(Icons.person_rounded,
                                          color: AppColors.secondary,
                                          size: 20),
                                    )
                                  : FallbackNetworkImage(
                                      url: user!.avatarUrl!,
                                      fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'CARTHAGE TRANSFER',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: widget.onNavigateToAlerts,
                          child: Icon(Icons.notifications_none_rounded,
                              color: AppColors.secondary, size: 24),
                        ),
                      ],
                    ),
                  ),

                  // Hero title
                  const SizedBox(height: 20),
                  Text(
                    l.t('my_rides'),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 38,
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
                  const SizedBox(height: 24),

                  // Underline tabs
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: AppColors.softBorder, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (final tab in ['Upcoming', 'History', 'Canceled'])
                          GestureDetector(
                            onTap: () => setState(() => _filter = tab),
                            child: Container(
                              margin: const EdgeInsets.only(right: 20),
                              padding: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _filter == tab
                                        ? AppColors.secondary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                _bookingFilterLabel(tab),
                                style: TextStyle(
                                  color: _filter == tab
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
                  const SizedBox(height: 20),

                  // â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  if (snapshot.connectionState == ConnectionState.waiting)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.secondary)),
                    )
                  else if (activeList.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.softBorder),
                      ),
                      child: Text(
                        _emptyRidesMessage(_filter),
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 14),
                      ),
                    )
                  else
                    for (final trip in activeList)
                      _BookingCard(
                        trip: trip,
                        rules: payload?.rules ?? const PricingRules(),
                        onChanged: _reload,
                      ),
                ],
              );
            },
          ),
        ),
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
                      fontWeight: FontWeight.w900,
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
                      '${trip.totalPrice.toStringAsFixed(2)} TND',
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

  Color _statusColor() {
    return switch (trip.status) {
      'completed' => AppColors.green,
      'cancelled' || 'rejected' => AppColors.danger,
      'assigned' ||
      'started' ||
      'arrived' =>
        AppColors.isDark ? AppColors.secondaryLight : AppColors.lightAccentText,
      _ => AppColors.accentText,
    };
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const SizedBox(height: 18),
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
                    fontWeight: FontWeight.w900,
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
                      fontWeight: FontWeight.w900,
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
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: Icon(Icons.remove_circle_outline_rounded),
            color: AppColors.textSecondary,
          ),
          Text(
            '$value',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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

  const _FavoritesTab({this.onNavigateToProfile});

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
    final user = AuthService.instance.currentUser;

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
                    // Top bar
                    SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          Icon(Icons.menu_rounded,
                              color: AppColors.secondary, size: 24),
                          Expanded(
                            child: Text(
                              'CARTHAGE TRANSFER',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onNavigateToProfile,
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: ClipOval(
                                child: user?.avatarUrl == null ||
                                        (user?.avatarUrl?.isEmpty ?? true)
                                    ? Container(
                                        color: AppColors.surfaceElevated,
                                        alignment: Alignment.center,
                                        child: Icon(Icons.person_rounded,
                                            color: AppColors.secondary,
                                            size: 18),
                                      )
                                    : FallbackNetworkImage(
                                        url: user!.avatarUrl!,
                                        fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.secondary),
                        ),
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

class _FavoriteTile extends StatelessWidget {
  final FavoriteLocation item;
  final VoidCallback? onDelete;

  const _FavoriteTile({required this.item, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              _iconForType(item.type),
              color: AppColors.secondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
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
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.textMuted,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'home' => Icons.home_outlined,
      'work' => Icons.business_center_outlined,
      'airport' => Icons.flight_takeoff_rounded,
      'hotel' => Icons.king_bed_outlined,
      _ => Icons.location_on_outlined,
    };
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

class _GlowBlob extends StatelessWidget {
  final Color color;

  const _GlowBlob({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double radius;

  const _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 6.0,
    this.dashSpace = 5.0,
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

  @override
  void dispose() {
    _label.dispose();
    _address.dispose();
    super.dispose();
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
            label: l.t('label'),
            hint: l.t('favorite_label_hint'),
            icon: Icons.label_outline_rounded,
          ),
          const SizedBox(height: 14),
          _PremiumSheetField(
            controller: _address,
            label: l.t('address'),
            hint: l.t('street_hint'),
            icon: Icons.location_on_outlined,
          ),
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

  const _PremiumSheetField({
    required this.controller,
    required this.label,
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


class _RewardsScreen extends StatelessWidget {
  const _RewardsScreen();

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    return LuxuryScaffold(
      title: l.t('rewards'),
      subtitle: l.t('rewards_subtitle'),
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: Builder(
        builder: (context) {
          // Demo rewards data — static, no backend dependency.
          // Tiers: Silver (0-4), Gold (5-14), Black (15+).
          const completed = 8;
          const tier = 'Gold';
          const nextTier = 'Black';
          const nextThreshold = 15;
          final toNext = (nextThreshold - completed).clamp(0, nextThreshold);
          final tierProgress =
              (completed / nextThreshold).clamp(0.0, 1.0).toDouble();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _RewardsHero(),
              const SizedBox(height: 18),
              _TierSummaryCard(
                tier: tier,
                completed: completed,
                nextTier: nextTier,
                toNext: toNext,
                progress: tierProgress,
              ),
              const SizedBox(height: 18),
              _RewardProgressCard(
                icon: Icons.card_giftcard_rounded,
                iconColor: AppColors.purple,
                title: '${completed.clamp(0, 5)} / 5 ${l.t('rides')}',
                value: (completed / 5).clamp(0, 1).toDouble(),
                trailing: completed >= 5 ? l.t('done') : l.t('earn'),
              ),
              const SizedBox(height: 10),
              _RewardProgressCard(
                icon: Icons.redeem_rounded,
                iconColor: AppColors.secondary,
                title: '${completed.clamp(0, 10)} / 10 ${l.t('rides')}',
                value: (completed / 10).clamp(0, 1).toDouble(),
                trailing: completed >= 10 ? l.t('done') : l.t('earn'),
              ),
              const SizedBox(height: 22),
              Text(
                l.t('available_promo_codes'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              _PromoRewardCard(
                code: 'CDHC5',
                rides: '5 ${l.t('rides')}',
                discount: '5% Discount',
              ),
              const SizedBox(height: 10),
              _PromoRewardCard(
                code: 'CDHC10',
                rides: '10 ${l.t('rides')}',
                discount: '10% Discount',
              ),
            ],
          );
        },
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
                        fontWeight: FontWeight.w900,
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
                      fontWeight: FontWeight.w900,
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
            '$toNext more rides to reach ${nextTier.toUpperCase()}',
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
                    fontWeight: FontWeight.w900,
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

class _RewardProgressCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final double value;
  final String trailing;

  const _RewardProgressCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      padding: const EdgeInsets.all(14),
      radius: 14,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconColor.withValues(alpha: 0.55)),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      trailing,
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 7,
                    backgroundColor: AppColors.isDark
                        ? const Color(0xFF070707)
                        : const Color(0xFFE8DDC6),
                    color: AppColors.secondary,
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

class _PromoRewardCard extends StatelessWidget {
  final String code;
  final String rides;
  final String discount;

  const _PromoRewardCard({
    required this.code,
    required this.rides,
    required this.discount,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      radius: 14,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  code,
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
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
          const SizedBox(width: 12),
          Icon(Icons.close_rounded, color: AppColors.textHint, size: 18),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenFavorites;

  const _ProfileTab({
    required this.onOpenBookings,
    required this.onOpenFavorites,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late UserModel _user;
  bool _refreshedProfile = false;

  @override
  void initState() {
    super.initState();
    _user = AuthService.instance.currentUser ?? AuthService.instance.demoUser;
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
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (file == null) return;
    try {
      final updated = await AuthService.instance.uploadAvatar(file);
      if (mounted) setState(() => _user = updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
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
            PremiumProfileTopBar(
              title: 'CARTHAGE TRANSFER',
              trailing: SizedBox(
                width: 34,
                height: 34,
                child: ClipOval(
                  child: _user.avatarUrl == null || _user.avatarUrl!.isEmpty
                      ? Container(
                          color: PremiumProfilePalette.surface(context),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.person_rounded,
                            color: PremiumProfilePalette.gold,
                            size: 18,
                          ),
                        )
                      : FallbackNetworkImage(
                          url: _user.avatarUrl!, fit: BoxFit.cover),
                ),
              ),
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
                  premiumProfileRoleBadge(_user).toUpperCase(),
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
            const SizedBox(height: 44),
            PremiumProfileActionCard(
              icon: Icons.calendar_month_outlined,
              title: l.t('my_bookings'),
              subtitle: l.t('my_bookings_desc'),
              onTap: widget.onOpenBookings,
            ),
            PremiumProfileActionCard(
              icon: Icons.star_border_rounded,
              title: l.t('favorites'),
              subtitle: l.t('favorites_subtitle'),
              onTap: widget.onOpenFavorites,
            ),
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
              icon: Icons.auto_awesome_rounded,
              title: 'Virtual Assistant',
              subtitle: 'AI-powered travel concierge — AVA',
              onTap: () => Navigator.of(context)
                  .pushNamed(AppRoutes.assistant),
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
                                style: TextStyle(fontWeight: FontWeight.w900),
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
                Text(title, style: TextStyle(fontWeight: FontWeight.w900)),
                Text(value, style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
