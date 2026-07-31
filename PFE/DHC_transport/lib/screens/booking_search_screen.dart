import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../core/constants/maps_config.dart';
import '../core/services/directions_service.dart';
import '../core/services/places_service.dart';
import '../core/services/pricing_service.dart';
import '../core/utils/tn_locations.dart';
import '../models/booking_data.dart';
import '../shared/widgets/client/premium_client_components.dart';

class BookingSearchScreen extends StatefulWidget {
  final ValueChanged<BookingData> onSearch;

  const BookingSearchScreen({super.key, required this.onSearch});

  @override
  State<BookingSearchScreen> createState() => _BookingSearchScreenState();
}

class _BookingSearchScreenState extends State<BookingSearchScreen> {
  // ── Text / focus ────────────────────────────────────────────────────────────
  final _pickupCtrl =
      TextEditingController(text: 'Tunis-Carthage Airport (TUN)');
  final _destCtrl = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus = FocusNode();

  // ── Coordinates ──────────────────────────────────────────────────────────────
  LatLng? _pickupLatLng;
  LatLng? _destLatLng;

  // ── Autocomplete ────────────────────────────────────────────────────────────
  List<PlaceSuggestion> _pickupSuggestions = [];
  List<PlaceSuggestion> _destSuggestions = [];
  Timer? _pickupDebounce;
  Timer? _destDebounce;
  static const _places = PlacesService(kMapsApiKey);

  // ── Road routing ────────────────────────────────────────────────────────────
  static const _directions = DirectionsService(kMapsApiKey);
  List<LatLng> _routePoints = [];
  LatLng? _lastRoutedPickup;
  LatLng? _lastRoutedDest;

  // ── Map controller ───────────────────────────────────────────────────────────
  GoogleMapController? _mapController;

  // ── Form state ───────────────────────────────────────────────────────────────
  PricingRules _rules = const PricingRules();
  String _tripType = 'one-way';
  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  DateTime? _returnDate;
  TimeOfDay? _returnTime;
  int _passengers = 1;
  int _luggage = 1;

  @override
  void initState() {
    super.initState();
    _loadRules();
    _pickupLatLng = TnLocations.resolve(_pickupCtrl.text);
    _pickupCtrl.addListener(_onPickupChanged);
    _destCtrl.addListener(_onDestChanged);
    _pickupFocus.addListener(_refresh);
    _destFocus.addListener(_refresh);
  }

  Future<void> _loadRules() async {
    final rules = await const PricingService().rules();
    if (mounted) setState(() => _rules = rules);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  // ── Autocomplete ─────────────────────────────────────────────────────────────

  void _onPickupChanged() {
    _pickupLatLng = null;
    _pickupDebounce?.cancel();
    _pickupDebounce = Timer(
        const Duration(milliseconds: 400), () => _fetchSuggestions(true));
    _refresh();
  }

  void _onDestChanged() {
    _destLatLng = null;
    _destDebounce?.cancel();
    _destDebounce = Timer(
        const Duration(milliseconds: 400), () => _fetchSuggestions(false));
    _refresh();
  }

  Future<void> _fetchSuggestions(bool isPickup) async {
    final query = isPickup ? _pickupCtrl.text : _destCtrl.text;
    final hasFocus =
        isPickup ? _pickupFocus.hasFocus : _destFocus.hasFocus;
    if (!hasFocus || query.trim().length < 2) {
      if (mounted) {
        setState(() {
          if (isPickup) _pickupSuggestions = [];
          else _destSuggestions = [];
        });
      }
      return;
    }
    final results = await _places.autocomplete(query);
    if (!mounted) return;
    setState(() {
      if (isPickup) _pickupSuggestions = results;
      else _destSuggestions = results;
    });
  }

  Future<void> _onSuggestionSelected(bool isPickup, PlaceSuggestion s) async {
    final ctrl = isPickup ? _pickupCtrl : _destCtrl;
    final focus = isPickup ? _pickupFocus : _destFocus;
    ctrl.text = s.description;
    focus.unfocus();
    setState(() {
      if (isPickup) _pickupSuggestions = [];
      else _destSuggestions = [];
    });
    final latlng = await _places.getCoordinates(s.placeId);
    if (!mounted || latlng == null) return;
    setState(() {
      if (isPickup) _pickupLatLng = latlng;
      else _destLatLng = latlng;
    });
    // Non-blocking: fetch road route and fit camera once coordinates are known
    _fetchRoute();
    _fitBounds();
  }

  // ── Directions ───────────────────────────────────────────────────────────────

  Future<void> _fetchRoute() async {
    final p = _resolvedPickup, d = _resolvedDest;
    if (p == null || d == null) {
      if (mounted && _routePoints.isNotEmpty) {
        setState(() => _routePoints = []);
      }
      return;
    }
    if (p == _lastRoutedPickup && d == _lastRoutedDest) return;
    _lastRoutedPickup = p;
    _lastRoutedDest = d;
    final points = await _directions.getRoute(p, d);
    if (mounted) setState(() => _routePoints = points);
  }

  // ── Camera ───────────────────────────────────────────────────────────────────

  Future<void> _fitBounds() async {
    final p = _resolvedPickup, d = _resolvedDest;
    if (_mapController == null || p == null || d == null) return;
    final sw = LatLng(
      p.latitude < d.latitude ? p.latitude : d.latitude,
      p.longitude < d.longitude ? p.longitude : d.longitude,
    );
    final ne = LatLng(
      p.latitude > d.latitude ? p.latitude : d.latitude,
      p.longitude > d.longitude ? p.longitude : d.longitude,
    );
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: sw, northeast: ne), 100),
      );
    } catch (_) {}
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  LatLng? get _resolvedPickup =>
      _pickupLatLng ?? TnLocations.resolve(_pickupCtrl.text);

  LatLng? get _resolvedDest =>
      _destLatLng ?? TnLocations.resolve(_destCtrl.text);

  Set<Marker> get _markers {
    final pickup = _pickupCtrl.text;
    final dest = _destCtrl.text;
    final p = _resolvedPickup, d = _resolvedDest;
    final markers = <Marker>{};
    if (p != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: p,
        infoWindow:
            InfoWindow(title: pickup.isEmpty ? 'Pickup' : pickup),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen),
      ));
    }
    if (d != null) {
      markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: d,
        infoWindow:
            InfoWindow(title: dest.isEmpty ? 'Destination' : dest),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange),
      ));
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    if (_routePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: const Color(0xFFC8A96B),
        width: 5,
      ),
    };
  }

  CameraPosition get _initialCamera {
    final p = _resolvedPickup;
    if (p != null) return CameraPosition(target: p, zoom: 10);
    return const CameraPosition(
        target: TnLocations.tunisiaCenter, zoom: 6);
  }

  // ── Form logic ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    _pickupDebounce?.cancel();
    _destDebounce?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isReturn}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isReturn) _returnDate = picked;
      else _departureDate = picked;
    });
  }

  Future<void> _pickTime({required bool isReturn}) async {
    final picked = await showTimePicker(
        context: context, initialTime: TimeOfDay.now());
    if (picked == null) return;
    setState(() {
      if (isReturn) _returnTime = picked;
      else _departureTime = picked;
    });
  }

  void _submit() {
    final pickup = _pickupCtrl.text.trim();
    final destination = _destCtrl.text.trim();
    if (pickup.isEmpty || destination.isEmpty) {
      _showSnack('Please enter pickup location and destination');
      return;
    }
    if (_departureDate == null || _departureTime == null) {
      _showSnack('Please select departure date and time');
      return;
    }
    if (_tripType == 'round-trip' &&
        (_returnDate == null || _returnTime == null)) {
      _showSnack('Please select return date and time');
      return;
    }
    // Resolved coordinates power the real distance-based price quote.
    final pickupPos = _resolvedPickup;
    final destPos = _resolvedDest;
    final data = BookingData(
      pickup: pickup,
      destination: destination,
      tripType: _tripType,
      departureDate: DateFormat('yyyy-MM-dd').format(_departureDate!),
      departureTime: _departureTime!.format(context),
      returnDate: _returnDate == null
          ? ''
          : DateFormat('yyyy-MM-dd').format(_returnDate!),
      returnTime: _returnTime?.format(context) ?? '',
      passengers: _passengers,
      luggageCount: _luggage,
      pickupLat: pickupPos?.latitude,
      pickupLng: pickupPos?.longitude,
      destinationLat: destPos?.latitude,
      destinationLng: destPos?.longitude,
    );
    if (!const PricingService().respectsMinimumBooking(data, _rules)) {
      _showSnack(
          'Bookings must be at least ${_rules.minimumBookingHours} hours ahead.');
      return;
    }
    widget.onSearch(data);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateLabel(DateTime? date) =>
      date == null ? 'Select' : DateFormat('MMM d, yyyy').format(date);

  String _timeLabel(TimeOfDay? time) =>
      time == null ? 'Select' : time.format(context);

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Full-screen map ─────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              markers: _markers,
              polylines: _polylines,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer()),
              },
              onMapCreated: (c) {
                _mapController = c;
                _fitBounds();
              },
            ),
          ),

          // ── Bottom form sheet ───────────────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.22,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.22, 0.55, 0.92],
            builder: (ctx, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1F),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 6),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Form
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: EdgeInsets.fromLTRB(
                          20, 10, 20,
                          MediaQuery.of(ctx).padding.bottom + 32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _TripTypeToggle(
                              value: _tripType,
                              onChanged: (v) =>
                                  setState(() => _tripType = v),
                            ),
                            const SizedBox(height: 14),
                            _LocationCard(
                              controller: _pickupCtrl,
                              focusNode: _pickupFocus,
                              label: 'PICKUP LOCATION',
                              hint: 'Airport, hotel, or address',
                              icon: Icons.radio_button_checked_rounded,
                              highlighted: true,
                              suggestions: _pickupFocus.hasFocus
                                  ? _pickupSuggestions
                                  : [],
                              onSuggestionSelected: (s) =>
                                  _onSuggestionSelected(true, s),
                            ),
                            const SizedBox(height: 12),
                            _LocationCard(
                              controller: _destCtrl,
                              focusNode: _destFocus,
                              label: 'DESTINATION',
                              hint: 'Hotel, city, or address',
                              icon: Icons.location_on_outlined,
                              highlighted: false,
                              suggestions: _destFocus.hasFocus
                                  ? _destSuggestions
                                  : [],
                              onSuggestionSelected: (s) =>
                                  _onSuggestionSelected(false, s),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _PickerTile(
                                    icon: Icons.calendar_today_outlined,
                                    label: 'DATE',
                                    value: _dateLabel(_departureDate),
                                    onTap: () =>
                                        _pickDate(isReturn: false),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _PickerTile(
                                    icon: Icons.schedule_rounded,
                                    label: 'TIME',
                                    value: _timeLabel(_departureTime),
                                    onTap: () =>
                                        _pickTime(isReturn: false),
                                  ),
                                ),
                              ],
                            ),
                            if (_tripType == 'round-trip') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _PickerTile(
                                      icon: Icons.event_repeat_rounded,
                                      label: 'RETURN',
                                      value: _dateLabel(_returnDate),
                                      onTap: () =>
                                          _pickDate(isReturn: true),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _PickerTile(
                                      icon: Icons.schedule_rounded,
                                      label: 'RETURN TIME',
                                      value: _timeLabel(_returnTime),
                                      onTap: () =>
                                          _pickTime(isReturn: true),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            _CounterRow(
                              icon: Icons.groups_rounded,
                              label: 'Passengers',
                              value: _passengers,
                              onChanged: (v) =>
                                  setState(() => _passengers = v),
                            ),
                            const SizedBox(height: 10),
                            _CounterRow(
                              icon: Icons.luggage_rounded,
                              label: 'Luggage',
                              value: _luggage,
                              onChanged: (v) =>
                                  setState(() => _luggage = v),
                            ),
                            const SizedBox(height: 28),
                            PremiumPrimaryButton(
                              text: 'Search & Book',
                              leadingIcon: Icons.arrow_forward_rounded,
                              onTap: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Dynamic Island pill title ───────────────────────────────────
          Positioned(
            top: topPad + 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xE6000000),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Text(
                  'Book a Transfer',
                  style: TextStyle(
                    color: Color(0xFFC8A96B),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // ── Back button (top-left, floating on map) ─────────────────────
          Positioned(
            top: topPad + 8,
            left: 14,
            child: PremiumIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trip type toggle ───────────────────────────────────────────────────────────

class _TripTypeToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _TripTypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 56,
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _item(context, 'one-way', 'One Way'),
            _item(context, 'round-trip', 'Round Trip'),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, String itemValue, String label) {
    final active = value == itemValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(itemValue),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? PremiumClientPalette.goldDeep
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? const Color(0xFF402D00)
                  : Colors.white.withValues(alpha: 0.70),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Location field with Places autocomplete dropdown ──────────────────────────

class _LocationCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool highlighted;
  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSuggestionSelected;

  const _LocationCard({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    required this.highlighted,
    required this.suggestions,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFFE9E1DA);
    const mutedColor = Color(0xFF8A8480);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? PremiumClientPalette.gold.withValues(alpha: 0.22)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: highlighted
                      ? PremiumClientPalette.goldDeep
                          .withValues(alpha: 0.18)
                      : const Color(0xFF1C1C1F),
                ),
                child: Icon(
                  icon,
                  color: highlighted
                      ? PremiumClientPalette.gold
                      : mutedColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: mutedColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: hint,
                        hintStyle: const TextStyle(
                          color: Color(0xFF4A4540),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: PremiumClientPalette.gold.withValues(alpha: 0.16),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final s in suggestions)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSuggestionSelected(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: PremiumClientPalette.gold,
                            size: 16,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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

// ── Date / time picker tile ────────────────────────────────────────────────────

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
    const textColor = Color(0xFFE9E1DA);
    final waiting = value == 'Select';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: const Color(0xFF6A6460), size: 14),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6A6460),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: waiting
                    ? PremiumClientPalette.gold
                    : textColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Passenger / luggage counter ────────────────────────────────────────────────

class _CounterRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _CounterRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFFE9E1DA);
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8A8480), size: 21),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _CounterBtn(
            icon: Icons.remove_rounded,
            onTap: value <= 1 ? null : () => onChanged(value - 1),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _CounterBtn(
            icon: Icons.add_rounded,
            onTap: () => onChanged(value + 1),
            accent: true,
          ),
        ],
      ),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;

  const _CounterBtn({required this.icon, this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: accent && enabled
                ? PremiumClientPalette.gold
                : PremiumClientPalette.gold.withValues(alpha: 0.28),
          ),
        ),
        child: Icon(
          icon,
          color: enabled
              ? PremiumClientPalette.gold
              : Colors.white.withValues(alpha: 0.25),
          size: 16,
        ),
      ),
    );
  }
}
