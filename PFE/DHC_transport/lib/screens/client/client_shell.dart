import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/favorite_location.dart';
import '../../core/models/transport_trip.dart';
import '../../core/models/user_model.dart';
import '../../core/routing/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/favorite_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/pricing_service.dart';
import '../../core/services/reward_service.dart';
import '../../core/services/trip_service.dart';
import '../../data/home_data.dart';
import '../../models/booking_data.dart';
import '../../models/vehicle.dart';
import '../../shared/widgets/common/luxury_components.dart';
import '../../widgets/common/fallback_network_image.dart';
import '../../widgets/home/booking_card.dart';
import '../booking_fleet_screen.dart';
import '../destinations_screen.dart';
import '../edit_profile_screen.dart';
import '../services_screen.dart';
import '../vehicles_screen.dart';

class ClientShell extends StatefulWidget {
  final int initialIndex;

  const ClientShell({super.key, this.initialIndex = 0});

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  late int _index;
  String _language = 'English';
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
    final tabs = [
      _ClientHomeTab(
        hasUnread: _unreadCount > 0,
        onStartBooking: _startBooking,
        onOpenVehicles: () => _push(const VehiclesScreen()),
        onOpenServices: () => _push(const ServicesScreen()),
        onOpenDestinations: () => _push(const DestinationsScreen()),
        onOpenAlerts: () => setState(() => _index = 3),
      ),
      const _BookingsTab(),
      const _FavoritesTab(),
      _AlertsTab(
        onUnreadCountChanged: (count) {
          if (count != _unreadCount) setState(() => _unreadCount = count);
        },
      ),
      _ProfileTab(
        language: _language,
        onLanguageChanged: (value) => setState(() => _language = value),
        onOpenBookings: () => setState(() => _index = 1),
        onOpenFavorites: () => setState(() => _index = 2),
        onOpenRewards: () => _push(const _RewardsScreen()),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LuxuryBackdrop(child: IndexedStack(index: _index, children: tabs)),
      bottomNavigationBar: LuxuryBottomNav(
        index: _index,
        onChanged: (value) => setState(() => _index = value),
        badged: _unreadCount > 0 ? const {3} : const {},
        items: const [
          LuxuryBottomNavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          LuxuryBottomNavItem(
            icon: Icons.event_note_outlined,
            activeIcon: Icons.event_note_rounded,
            label: 'Bookings',
          ),
          LuxuryBottomNavItem(
            icon: Icons.favorite_border_rounded,
            activeIcon: Icons.favorite_rounded,
            label: 'Favorites',
          ),
          LuxuryBottomNavItem(
            icon: Icons.notifications_none_rounded,
            activeIcon: Icons.notifications_rounded,
            label: 'Alerts',
          ),
          LuxuryBottomNavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _ClientHomeTab extends StatelessWidget {
  final bool hasUnread;
  final ValueChanged<BookingData> onStartBooking;
  final VoidCallback onOpenVehicles;
  final VoidCallback onOpenServices;
  final VoidCallback onOpenDestinations;
  final VoidCallback onOpenAlerts;

  const _ClientHomeTab({
    required this.hasUnread,
    required this.onStartBooking,
    required this.onOpenVehicles,
    required this.onOpenServices,
    required this.onOpenDestinations,
    required this.onOpenAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final firstName = (user?.name.split(' ').first ?? 'Guest').trim();
    final isGuest = AuthService.instance.isGuest;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 102),
          children: [
            _HomeHeader(
            firstName: firstName,
            hasUnread: hasUnread,
            onOpenAlerts: onOpenAlerts,
          ),
            const SizedBox(height: 18),
            if (isGuest) ...[
              _GuestNotice(onLogin: () => _goLogin(context)),
              const SizedBox(height: 14),
            ],
            BookingCard(onSearch: onStartBooking),
            const SizedBox(height: 22),
            const _TrustStrip(),
            const SizedBox(height: 24),
            LuxurySectionHeader(
              title: 'Vehicle categories',
              subtitle: 'Browse the fleet before booking',
              actionLabel: 'View all',
              onAction: onOpenVehicles,
            ),
            const SizedBox(height: 12),
            _VehiclePreview(onTap: onOpenVehicles),
            const SizedBox(height: 24),
            LuxurySectionHeader(
              title: 'Popular destinations',
              subtitle: 'Airport transfers and fixed routes',
              actionLabel: 'Routes',
              onAction: onOpenDestinations,
            ),
            const SizedBox(height: 12),
            _PopularRoutes(onSelect: onStartBooking),
            const SizedBox(height: 24),
            const LuxurySectionHeader(
              title: 'Services',
              subtitle: 'Premium transfer options for travelers',
            ),
            const SizedBox(height: 12),
            _ServiceGrid(onOpenServices: onOpenServices),
          ],
        ),
      ),
    );
  }

  void _goLogin(BuildContext context) {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }
}

class _HomeHeader extends StatelessWidget {
  final String firstName;
  final bool hasUnread;
  final VoidCallback onOpenAlerts;

  const _HomeHeader({
    required this.firstName,
    required this.hasUnread,
    required this.onOpenAlerts,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.menu_rounded, color: AppColors.secondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good morning',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onOpenAlerts,
          customBorder: const CircleBorder(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldBorder),
                  color: AppColors.surface,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.secondary,
                ),
              ),
              if (hasUnread)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuestNotice extends StatelessWidget {
  final VoidCallback onLogin;

  const _GuestNotice({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Browse vehicles and prices. Login is required before booking.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
          ),
          TextButton(
            onPressed: onLogin,
            child: const Text('Login',
                style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.verified_user_outlined, 'Licensed', 'Drivers'),
      (Icons.sell_outlined, 'Fixed', 'Pricing'),
      (Icons.headset_mic_outlined, '24/7', 'Support'),
      (Icons.shield_outlined, 'Safe', 'Secure'),
    ];
    return Row(
      children: [
        for (final item in items) ...[
          Expanded(
            child: LuxuryCard(
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
              radius: 16,
              child: Column(
                children: [
                  Icon(item.$1, color: AppColors.secondary, size: 20),
                  const SizedBox(height: 7),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    item.$3,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (item != items.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _VehiclePreview extends StatelessWidget {
  final VoidCallback onTap;

  const _VehiclePreview({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 198,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: HomeData.vehicles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final vehicle = HomeData.vehicles[index];
          return LuxuryCard(
            onTap: onTap,
            padding: EdgeInsets.zero,
            radius: 18,
            child: SizedBox(
              width: 158,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                    child: FallbackNetworkImage(
                      url: vehicle.image,
                      height: 94,
                      width: double.infinity,
                      fit: BoxFit.contain,
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
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${vehicle.seatCount} seats - ${vehicle.bags} bags',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${vehicle.price} TND',
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
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
        },
      ),
    );
  }
}

class _PopularRoutes extends StatelessWidget {
  final ValueChanged<BookingData> onSelect;

  const _PopularRoutes({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 178,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: HomeData.popularRoutes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final route = HomeData.popularRoutes[index];
          return LuxuryCard(
            onTap: () => onSelect(
              BookingData(pickup: route.from, destination: route.to),
            ),
            padding: EdgeInsets.zero,
            radius: 18,
            child: SizedBox(
              width: 206,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(18)),
                    child: FallbackNetworkImage(
                      url: route.image,
                      height: 88,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${route.from} to',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            route.to,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                '${route.price} TND',
                                style: const TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                route.time,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
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
        },
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  final VoidCallback onOpenServices;

  const _ServiceGrid({required this.onOpenServices});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.flight_takeoff_rounded, 'Airport', 'Meet and greet transfers'),
      (Icons.business_center_outlined, 'Business', 'Executive city rides'),
      (Icons.groups_rounded, 'Group', 'Van and family transfers'),
    ];
    return Column(
      children: [
        for (final item in items)
          LuxuryCard(
            onTap: onOpenServices,
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(item.$1, color: AppColors.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$2,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        item.$3,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
              ],
            ),
          ),
      ],
    );
  }
}

class _BookingsTab extends StatefulWidget {
  const _BookingsTab();

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
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<_BookingsPayload>(
          future: _future,
          builder: (context, snapshot) {
            final payload = snapshot.data;
            final upcoming = payload?.history['upcoming'] ?? const [];
            final past = payload?.history['past'] ?? const [];
            final cancelled =
                past.where((trip) => trip.status == 'cancelled').toList();
            final activeList = switch (_filter) {
              'History' => past,
              'Canceled' => cancelled,
              _ => upcoming,
            };

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 104),
              children: [
                const LuxuryHeader(
                  title: 'My Rides',
                  subtitle: 'Upcoming transfers and ride history',
                ),
                const SizedBox(height: 16),
                _SegmentedTabs(
                  value: _filter,
                  values: const ['Upcoming', 'History', 'Canceled'],
                  onChanged: (value) => setState(() => _filter = value),
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (activeList.isEmpty)
                  LuxuryCard(
                    child: Text(
                      'No ${_filter.toLowerCase()} rides yet.',
                      style: const TextStyle(color: AppColors.textSecondary),
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
    );
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

  const _SegmentedTabs({
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
                    color: value == item
                        ? AppColors.secondary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    item,
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
    final canModify = _canModify();
    final canCancel = _canCancel();
    return LuxuryCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.vehicleClass.isEmpty
                      ? trip.vehicleType
                      : trip.vehicleClass,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              LuxuryStatusChip(label: trip.status, color: _statusColor()),
            ],
          ),
          const SizedBox(height: 13),
          _RouteLine(from: trip.pickupLocation, to: trip.destinationName),
          const SizedBox(height: 13),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: AppColors.textMuted, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${trip.departureDate} ${trip.departureTime}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${trip.totalPrice.toStringAsFixed(0)} TND',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (trip.status != 'completed' && trip.status != 'cancelled') ...[
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: LuxuryButton(
                    text: 'Modify',
                    height: 42,
                    variant: LuxuryButtonVariant.outline,
                    onPressed: canModify
                        ? () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _ModifyBookingScreen(
                                  trip: trip,
                                  rules: rules,
                                ),
                              ),
                            );
                            onChanged();
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LuxuryButton(
                    text: 'Cancel',
                    height: 42,
                    variant: LuxuryButtonVariant.outline,
                    onPressed: canCancel
                        ? () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _CancelBookingScreen(
                                  trip: trip,
                                  rules: rules,
                                ),
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
      'assigned' || 'started' || 'arrived' => AppColors.secondaryLight,
      _ => AppColors.secondary,
    };
  }
}

class _RouteLine extends StatelessWidget {
  final String from;
  final String to;

  const _RouteLine({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          children: [
            Icon(Icons.radio_button_checked_rounded,
                color: AppColors.secondary, size: 17),
            SizedBox(height: 18),
            Icon(Icons.location_on_rounded, color: AppColors.green, size: 17),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                from,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                to,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
            'Modification is only allowed ${widget.rules.modificationLimitHours} hours before departure.',
          ),
        ),
      );
      return;
    }

    setState(() => _busy = true);
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
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Modify Booking',
      subtitle:
          'Allowed until ${widget.rules.modificationLimitHours} hours before pickup',
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LuxuryTextField(
            controller: _pickup,
            label: 'Pickup',
            hintText: 'Pickup location',
            icon: Icons.my_location_rounded,
          ),
          const SizedBox(height: 14),
          LuxuryTextField(
            controller: _destination,
            label: 'Destination',
            hintText: 'Destination',
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PickerTile(
                  icon: Icons.calendar_month_rounded,
                  label: 'Date',
                  value: DateFormat('MMM d, yyyy').format(_date),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerTile(
                  icon: Icons.schedule_rounded,
                  label: 'Time',
                  value: _time.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StepperRow(
            icon: Icons.groups_rounded,
            label: 'Passengers',
            value: _passengers,
            onChanged: (value) => setState(() => _passengers = value),
          ),
          const SizedBox(height: 10),
          _StepperRow(
            icon: Icons.luggage_rounded,
            label: 'Luggage',
            value: _luggage,
            onChanged: (value) => setState(() => _luggage = value),
          ),
          const SizedBox(height: 18),
          LuxuryButton(
            text: 'Save Changes',
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
    final allowed = const PricingService().canChangeBooking(
      widget.trip.departureDate,
      widget.trip.departureTime,
      widget.rules.cancellationLimitHours,
    );
    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cancellation is only allowed ${widget.rules.cancellationLimitHours} hours before departure.',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    await const TripService().updateStatus(widget.trip.id, 'cancelled');
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Cancel Booking',
      subtitle:
          'Allowed until ${widget.rules.cancellationLimitHours} hours before pickup',
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
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
                  style: const TextStyle(
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
                  label: 'Departure',
                  value:
                      '${widget.trip.departureDate} ${widget.trip.departureTime}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const LuxuryCard(
            child: Text(
              'This will mark the reservation as cancelled. Your booking history will keep the record.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.45),
            ),
          ),
          const SizedBox(height: 18),
          LuxuryButton(
            text: 'Confirm Cancellation',
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.secondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(
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
                    style: const TextStyle(
                      color: AppColors.textPrimary,
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
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: AppColors.textSecondary,
          ),
          Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class _FavoritesTab extends StatefulWidget {
  const _FavoritesTab();

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
    setState(() => _future = const FavoriteService().listFavorites());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<FavoriteLocation>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? FavoriteService.defaults;
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 104),
            children: [
              LuxuryHeader(
                title: 'Favorites',
                subtitle: AuthService.instance.isGuest
                    ? 'Login to save personal locations'
                    : 'Home, work, airport, and custom locations',
                actions: [
                  IconButton(
                    onPressed: AuthService.instance.isAuthenticated
                        ? () => _showAddFavorite(context)
                        : null,
                    icon: const Icon(Icons.add_rounded,
                        color: AppColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final item in items)
                _FavoriteTile(
                  item: item,
                  onDelete: AuthService.instance.isAuthenticated
                      ? () async {
                          await const FavoriteService().deleteFavorite(item.id);
                          _reload();
                        }
                      : null,
                ),
              if (AuthService.instance.isAuthenticated) ...[
                const SizedBox(height: 12),
                LuxuryButton(
                  text: 'Add New Location',
                  onPressed: () => _showAddFavorite(context),
                  variant: LuxuryButtonVariant.outline,
                  icon: const Icon(Icons.add_location_alt_outlined),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showAddFavorite(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
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
    return LuxuryCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(_iconForType(item.type), color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  item.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.textMuted),
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
      _ => Icons.location_on_outlined,
    };
  }
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LuxuryHeader(title: 'Add Favorite', subtitle: 'Saved location'),
          const SizedBox(height: 16),
          LuxuryTextField(
            controller: _label,
            label: 'Label',
            hintText: 'Home, Work, Airport',
            icon: Icons.label_outline_rounded,
          ),
          const SizedBox(height: 14),
          LuxuryTextField(
            controller: _address,
            label: 'Address',
            hintText: 'Street, area, or landmark',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 14),
          _SegmentedTabs(
            value: _type,
            values: const ['home', 'work', 'airport', 'custom'],
            onChanged: (value) => setState(() => _type = value),
          ),
          const SizedBox(height: 18),
          LuxuryButton(text: 'Save Location', loading: _busy, onPressed: _save),
        ],
      ),
    );
  }
}

class _AlertsTab extends StatefulWidget {
  final ValueChanged<int> onUnreadCountChanged;

  const _AlertsTab({required this.onUnreadCountChanged});

  @override
  State<_AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends State<_AlertsTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await const NotificationService().listNotifications();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
      _reportUnread();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _reportUnread() {
    final count = _items.where((n) => n['read'] != true).length;
    widget.onUnreadCountChanged(count);
  }

  Future<void> _markRead(int index) async {
    final item = _items[index];
    if (item['read'] == true) return;
    final id = item['_id']?.toString() ?? '';
    setState(() => _items[index] = {...item, 'read': true});
    _reportUnread();
    try {
      await const NotificationService().markAsRead(id);
    } catch (_) {
      // Optimistic update — revert on error
      if (!mounted) return;
      setState(() => _items[index] = item);
      _reportUnread();
    }
  }

  Future<void> _markAllRead() async {
    final updated = _items.map((n) => {...n, 'read': true}).toList();
    setState(() => _items = updated);
    _reportUnread();
    try {
      await const NotificationService().markAllRead();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((n) => n['read'] != true).length;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.secondary,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 104),
          children: [
            LuxuryHeader(
              title: 'Alerts',
              subtitle: 'Booking updates and offers',
              actions: [
                if (unreadCount > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_items.isEmpty)
              const LuxuryCard(
                child: Text(
                  'No alerts yet. Booking updates will appear here.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              for (int i = 0; i < _items.length; i++)
                _AlertCard(
                  item: _items[i],
                  onTap: () => _markRead(i),
                ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _AlertCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] as String?)?.trim();
    final message = (item['message'] as String?)?.trim();
    final read = item['read'] == true;

    return LuxuryCard(
      onTap: read ? null : onTap,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      selected: !read,
      color: read ? AppColors.surface : AppColors.surfaceElevated,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: read ? 0.08 : 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: read ? 0.25 : 0.7),
              ),
            ),
            child: Icon(
              _iconFor(title, message),
              color: AppColors.secondary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title?.isNotEmpty == true
                            ? title!
                            : 'Reservation update',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (!read) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  message?.isNotEmpty == true
                      ? message!
                      : 'Your booking status changed.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatAlertTime(item['created_at']),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String? title, String? message) {
    final text = '${title ?? ''} ${message ?? ''}'.toLowerCase();
    if (text.contains('promo') || text.contains('reward')) {
      return Icons.local_offer_outlined;
    }
    if (text.contains('driver') || text.contains('ride')) {
      return Icons.directions_car_filled_outlined;
    }
    if (text.contains('booking') || text.contains('reservation')) {
      return Icons.event_available_outlined;
    }
    return Icons.notifications_none_rounded;
  }

  String _formatAlertTime(Object? value) {
    if (value == null) return 'Just now';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    return DateFormat('MMM d, HH:mm').format(parsed.toLocal());
  }
}

class _RewardsScreen extends StatelessWidget {
  const _RewardsScreen();

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Rewards',
      subtitle: 'Travel more, earn more',
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: const RewardService().getRewards(),
        builder: (context, snapshot) {
          final data = snapshot.data ?? const {};
          final completed =
              (data['completed_rides_count'] as num?)?.toInt() ?? 0;
          final promoCodes = (data['promo_codes'] as List? ?? const [])
              .map((item) => item.toString())
              .toList(growable: false);

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _RewardsHero(),
              const SizedBox(height: 18),
              _RewardProgressCard(
                icon: Icons.card_giftcard_rounded,
                iconColor: AppColors.purple,
                title: '${completed.clamp(0, 5)} / 5 Rides',
                value: (completed / 5).clamp(0, 1).toDouble(),
                trailing: completed >= 5 ? 'DONE' : 'EARN',
              ),
              const SizedBox(height: 10),
              _RewardProgressCard(
                icon: Icons.redeem_rounded,
                iconColor: AppColors.secondary,
                title: '${completed.clamp(0, 10)} / 10 Rides',
                value: (completed / 10).clamp(0, 1).toDouble(),
                trailing: completed >= 10 ? 'DONE' : 'EARN',
              ),
              const SizedBox(height: 22),
              const Text(
                'Available Promo Codes',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              _PromoRewardCard(
                code: promoCodes.contains('CDHC5') ? 'CDHC5' : 'CDHC5',
                rides: '5 Rides',
                discount: '5% Discount',
              ),
              const SizedBox(height: 10),
              _PromoRewardCard(
                code: promoCodes.contains('CDHC10') ? 'CDHC10' : 'CDHC10',
                rides: '10 Rides',
                discount: '10% Discount',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RewardsHero extends StatelessWidget {
  const _RewardsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA86605), Color(0xFF2A1702)],
        ),
        border: Border.all(color: AppColors.goldBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Your Rewards',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Travel more, earn more',
                  style: TextStyle(
                    color: AppColors.textSecondary,
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
              gradient: const LinearGradient(
                colors: [AppColors.secondaryLight, AppColors.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.45),
                  blurRadius: 18,
                ),
              ],
            ),
            child: const Icon(
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      trailing,
                      style: const TextStyle(
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
                    backgroundColor: const Color(0xFF070707),
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
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  rides,
                  style: const TextStyle(
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
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.close_rounded, color: AppColors.textHint, size: 18),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  final String language;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenRewards;

  const _ProfileTab({
    required this.language,
    required this.onLanguageChanged,
    required this.onOpenBookings,
    required this.onOpenFavorites,
    required this.onOpenRewards,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late UserModel _user;

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
  Widget build(BuildContext context) {
    final isGuest = AuthService.instance.isGuest;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 104),
        children: [
          LuxuryHeader(
            title: isGuest ? 'Guest Profile' : 'Profile',
            subtitle: 'Account, settings, and support',
            actions: [
              IconButton(
                onPressed: _editProfile,
                icon:
                    const Icon(Icons.edit_outlined, color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LuxuryCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _Avatar(user: _user),
                const SizedBox(height: 14),
                Text(
                  isGuest ? 'Guest browsing' : _user.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isGuest ? 'Login to reserve rides' : _user.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                LuxuryButton(
                  text: isGuest ? 'Login or Register' : 'Edit Profile',
                  onPressed: isGuest ? _goLogin : _editProfile,
                  variant: LuxuryButtonVariant.outline,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ProfileAction(
            icon: Icons.event_note_outlined,
            title: 'My Bookings',
            subtitle: 'Modify, cancel, or review reservations',
            onTap: widget.onOpenBookings,
          ),
          _ProfileAction(
            icon: Icons.favorite_border_rounded,
            title: 'Favorite Locations',
            subtitle: 'Home, work, airport, and custom places',
            onTap: widget.onOpenFavorites,
          ),
          _ProfileAction(
            icon: Icons.card_giftcard_outlined,
            title: 'Rewards',
            subtitle: 'Promo codes and ride milestones',
            onTap: widget.onOpenRewards,
          ),
          _ProfileAction(
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: widget.language,
            onTap: () => _openSettings(context),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.instance.mode,
            builder: (_, mode, __) => _ProfileAction(
              icon: Icons.dark_mode_outlined,
              title: 'Display Mode',
              subtitle: mode == ThemeMode.dark ? 'Dark mode' : 'Light mode',
              onTap: () => _openSettings(context),
            ),
          ),
          _ProfileAction(
            icon: Icons.headset_mic_outlined,
            title: 'Support',
            subtitle: '24/7 transfer assistance',
            onTap: _showSupport,
          ),
          const SizedBox(height: 16),
          LuxuryButton(
            text: isGuest ? 'Login' : 'Logout',
            onPressed: isGuest ? _goLogin : _logout,
            variant: isGuest
                ? LuxuryButtonVariant.primary
                : LuxuryButtonVariant.outline,
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SettingsScreen(
          language: widget.language,
          onLanguageChanged: widget.onLanguageChanged,
        ),
      ),
    );
  }

  void _showSupport() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              LuxuryHeader(title: 'Support', subtitle: 'Available 24/7'),
              SizedBox(height: 14),
              _SupportLine(
                icon: Icons.phone_outlined,
                title: 'Call support',
                value: '+216 71 000 000',
              ),
              _SupportLine(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'WhatsApp',
                value: 'Instant response',
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
  final String language;
  final ValueChanged<String> onLanguageChanged;

  const _SettingsScreen({
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryScaffold(
      title: 'Settings',
      subtitle: 'Language and display preferences',
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.secondary),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LuxurySectionHeader(title: 'Language'),
          const SizedBox(height: 10),
          _SegmentedTabs(
            value: language,
            values: const ['English', 'French'],
            onChanged: onLanguageChanged,
          ),
          const SizedBox(height: 18),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.instance.mode,
            builder: (_, mode, __) => LuxuryCard(
              child: Row(
                children: [
                  const Icon(Icons.dark_mode_outlined,
                      color: AppColors.secondary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dark mode',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Premium black and gold interface',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: mode == ThemeMode.dark,
                    activeThumbColor: AppColors.secondary,
                    activeTrackColor:
                        AppColors.secondary.withValues(alpha: 0.4),
                    onChanged: (dark) =>
                        ThemeService.instance.setDark(dark),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final UserModel user;

  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.secondary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.18),
            blurRadius: 28,
          ),
        ],
      ),
      child: ClipOval(
        child: user.avatarUrl == null
            ? Container(
                color: AppColors.surfaceElevated,
                alignment: Alignment.center,
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : FallbackNetworkImage(url: user.avatarUrl!, fit: BoxFit.cover),
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LuxuryCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Icon(icon, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
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
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(value, style: const TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
