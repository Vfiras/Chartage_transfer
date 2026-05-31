import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/services/pricing_service.dart';
import '../models/booking_data.dart';
import '../shared/widgets/client/premium_client_components.dart';
import 'booking_fleet_screen.dart';

const _tunisLocations = [
  'Tunis-Carthage Airport (TUN)',
  'Tunis-Carthage International Airport',
  'Tunis City Centre',
  'La Marsa',
  'Sidi Bou Said',
  'Hammamet',
  'Sousse',
  'Monastir Airport',
  'Djerba Airport',
  'Sfax',
  'Nabeul',
  'Tunis Gare Centrale',
  'Hotel du Lac',
  'Carthage Archaeological Site',
  'Bardo Museum',
  'Medina de Tunis',
  'Les Berges du Lac',
  'El Menzah',
  'Ariana',
  'Ben Arous',
  'Manouba',
];

class BookingSearchScreen extends StatefulWidget {
  final ValueChanged<BookingData> onSearch;

  const BookingSearchScreen({super.key, required this.onSearch});

  @override
  State<BookingSearchScreen> createState() => _BookingSearchScreenState();
}

class _BookingSearchScreenState extends State<BookingSearchScreen> {
  final _pickupController =
      TextEditingController(text: 'Tunis-Carthage Airport (TUN)');
  final _destinationController = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destinationFocus = FocusNode();

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
    _pickupController.addListener(_refresh);
    _destinationController.addListener(_refresh);
    _pickupFocus.addListener(_refresh);
    _destinationFocus.addListener(_refresh);
  }

  Future<void> _loadRules() async {
    final rules = await const PricingService().rules();
    if (mounted) setState(() => _rules = rules);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupFocus.dispose();
    _destinationFocus.dispose();
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
      if (isReturn) {
        _returnDate = picked;
      } else {
        _departureDate = picked;
      }
    });
  }

  Future<void> _pickTime({required bool isReturn}) async {
    final picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked == null) return;
    setState(() {
      if (isReturn) {
        _returnTime = picked;
      } else {
        _departureTime = picked;
      }
    });
  }

  void _submit() {
    final pickup = _pickupController.text.trim();
    final destination = _destinationController.text.trim();

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
    );

    if (!const PricingService().respectsMinimumBooking(data, _rules)) {
      _showSnack(
        'Bookings must be at least ${_rules.minimumBookingHours} hours ahead.',
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingFleetScreen(data: data)),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<String> _suggestionsFor(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    return _tunisLocations
        .where((location) => location.toLowerCase().contains(normalized))
        .take(5)
        .toList();
  }

  String _dateLabel(DateTime? date) =>
      date == null ? 'Select' : DateFormat('MMM d, yyyy').format(date);

  String _timeLabel(TimeOfDay? time) =>
      time == null ? 'Select' : time.format(context);

  @override
  Widget build(BuildContext context) {
    final pickup = _pickupController.text;
    final destination = _destinationController.text;

    return Scaffold(
      backgroundColor: PremiumClientTheme.background(context),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 42),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
                PremiumMapPreview(
                  pickup: pickup,
                  destination: destination,
                  height: 574,
                ),
                Transform.translate(
                  offset: const Offset(0, -96),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TripTypeToggle(
                          value: _tripType,
                          onChanged: (value) =>
                              setState(() => _tripType = value),
                        ),
                        const SizedBox(height: 20),
                        _LocationCard(
                          controller: _pickupController,
                          focusNode: _pickupFocus,
                          label: 'PICKUP LOCATION',
                          hint: 'Airport, hotel, or address',
                          icon: Icons.radio_button_checked_rounded,
                          highlighted: true,
                          suggestions: _pickupFocus.hasFocus
                              ? _suggestionsFor(pickup)
                              : const [],
                          onSuggestionSelected: (value) {
                            _pickupController.text = value;
                            _pickupFocus.unfocus();
                          },
                        ),
                        const SizedBox(height: 14),
                        _LocationCard(
                          controller: _destinationController,
                          focusNode: _destinationFocus,
                          label: 'DESTINATION',
                          hint: 'Hotel, city, or address',
                          icon: Icons.location_on_outlined,
                          highlighted: false,
                          suggestions: _destinationFocus.hasFocus
                              ? _suggestionsFor(destination)
                              : const [],
                          onSuggestionSelected: (value) {
                            _destinationController.text = value;
                            _destinationFocus.unfocus();
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _PickerTile(
                                icon: Icons.calendar_today_outlined,
                                label: 'DATE',
                                value: _dateLabel(_departureDate),
                                onTap: () => _pickDate(isReturn: false),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _PickerTile(
                                icon: Icons.schedule_rounded,
                                label: 'TIME',
                                value: _timeLabel(_departureTime),
                                onTap: () => _pickTime(isReturn: false),
                              ),
                            ),
                          ],
                        ),
                        if (_tripType == 'round-trip') ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _PickerTile(
                                  icon: Icons.event_repeat_rounded,
                                  label: 'RETURN',
                                  value: _dateLabel(_returnDate),
                                  onTap: () => _pickDate(isReturn: true),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _PickerTile(
                                  icon: Icons.schedule_rounded,
                                  label: 'RETURN TIME',
                                  value: _timeLabel(_returnTime),
                                  onTap: () => _pickTime(isReturn: true),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        _CounterRow(
                          icon: Icons.groups_rounded,
                          label: 'Passengers',
                          value: _passengers,
                          onChanged: (value) =>
                              setState(() => _passengers = value),
                        ),
                        const SizedBox(height: 14),
                        _CounterRow(
                          icon: Icons.luggage_rounded,
                          label: 'Luggage',
                          value: _luggage,
                          onChanged: (value) =>
                              setState(() => _luggage = value),
                        ),
                        const SizedBox(height: 40),
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
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 18, 30, 0),
                child: Row(
                  children: [
                    PremiumIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(
                      child: Text(
                        'Book a Transfer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PremiumClientPalette.gold,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                    const PremiumAvatar(size: 42),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripTypeToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _TripTypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PremiumGlassPanel(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 66,
        padding: const EdgeInsets.all(5),
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
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? PremiumClientPalette.goldDeep : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? const Color(0xFF402D00)
                  : PremiumClientTheme.text(context).withValues(alpha: 0.76),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool highlighted;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionSelected;

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
    final textColor = PremiumClientTheme.text(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 22, 22),
          decoration: BoxDecoration(
            color: PremiumClientTheme.surface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: highlighted
                  ? PremiumClientPalette.gold.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: highlighted
                      ? PremiumClientPalette.goldDeep.withValues(alpha: 0.20)
                      : PremiumClientTheme.elevated(context),
                ),
                child: Icon(
                  icon,
                  color: highlighted
                      ? PremiumClientPalette.gold
                      : textColor.withValues(alpha: 0.76),
                  size: 26,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.62),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.only(top: 8),
                        hintText: hint,
                        hintStyle: TextStyle(
                          color: textColor.withValues(alpha: 0.65),
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.add_rounded,
                color: textColor.withValues(alpha: 0.48),
                size: 28,
              ),
            ],
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: PremiumClientTheme.elevated(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: PremiumClientPalette.gold.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final suggestion in suggestions)
                  InkWell(
                    onTap: () => onSuggestionSelected(suggestion),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: PremiumClientPalette.gold,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
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
    final textColor = PremiumClientTheme.text(context);
    final waiting = value == 'Select';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 104,
        padding: const EdgeInsets.fromLTRB(24, 22, 20, 18),
        decoration: BoxDecoration(
          color: PremiumClientTheme.surface(context),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.7,
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
                color: waiting ? PremiumClientPalette.gold : textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    final textColor = PremiumClientTheme.text(context);
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: PremiumClientTheme.surface(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _CounterButton(
            icon: Icons.remove_rounded,
            onTap: value <= 1 ? null : () => onChanged(value - 1),
          ),
          SizedBox(
            width: 54,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _CounterButton(
            icon: Icons.add_rounded,
            onTap: () => onChanged(value + 1),
            accent: true,
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool accent;

  const _CounterButton({
    required this.icon,
    this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: accent && enabled
                ? PremiumClientPalette.gold
                : PremiumClientPalette.gold.withValues(alpha: 0.35),
          ),
        ),
        child: Icon(
          icon,
          color: enabled
              ? PremiumClientPalette.gold
              : PremiumClientTheme.text(context).withValues(alpha: 0.38),
          size: 19,
        ),
      ),
    );
  }
}
