import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/transport_api_client.dart';
import '../../../widgets/common/luxury_skeleton.dart';

/// Admin Pricing — per-vehicle pricing parameters dashboard.
///
/// Shows every vehicle in the fleet as a card with its live pricing values
/// (Chauffeur Booking System model: initial fee, per-km, per-hour, waypoint
/// rates…). Tapping a card opens an editor with one number field per
/// parameter; saving calls PUT /cars/{id} with the updated `pricing` object.
///
/// This replaces the old static surcharge-rules form. The surcharge endpoint
/// (PUT /pricing/rules) still exists and surcharges still apply at quote time.
class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  List<Map<String, dynamic>> _cars = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await TransportApiClient.instance.get('/cars/all');
      if (!mounted) return;
      setState(() {
        _cars = ((res['cars'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openEditor(Map<String, dynamic> car) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PricingEditSheet(car: car, onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Vehicle Pricing',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: Icon(Icons.refresh_rounded,
                        color: AppColors.accentText),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Live rates from the Chauffeur Booking System model. '
                'Tap a vehicle to edit its parameters.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      // Vehicle-pricing-card-shaped skeletons instead of a spinner.
      return const SkeletonCardList(count: 4, cardHeight: 132);
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              style: const TextStyle(color: AppColors.danger),
              textAlign: TextAlign.center),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        itemCount: _cars.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _VehiclePricingCard(
          car: _cars[i],
          onTap: () => _openEditor(_cars[i]),
        ),
      ),
    );
  }
}

class _VehiclePricingCard extends StatelessWidget {
  final Map<String, dynamic> car;
  final VoidCallback onTap;

  const _VehiclePricingCard({required this.car, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pricing = (car['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    final currency = pricing['currency']?.toString() ?? 'EUR';
    final unverified = car['pricing_verified'] == false;

    String fmt(dynamic v) =>
        v == null ? '—' : (v as num).toStringAsFixed(v % 1 == 0 ? 0 : 3);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.softBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    car['name']?.toString() ?? 'Vehicle',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (unverified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.chipPinkBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'VERIFY RATES',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.edit_rounded,
                    size: 16, color: AppColors.accentText),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${car['category'] ?? ''} · ${car['seats'] ?? '?'} pax · '
              '${car['luggage'] ?? '?'} bags',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _RateChip('Initial', '${fmt(pricing['initial_fee'])} $currency'),
                _RateChip('Return init',
                    '${fmt(pricing['initial_fee_return'])} $currency'),
                _RateChip('Per km', '${fmt(pricing['per_km'])} $currency'),
                _RateChip('Per hour', '${fmt(pricing['per_hour'])} $currency'),
                _RateChip('Waypoint',
                    '${fmt(pricing['per_waypoint'])} $currency'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  final String label;
  final String value;

  const _RateChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PricingEditSheet extends StatefulWidget {
  final Map<String, dynamic> car;
  final VoidCallback onSaved;

  const _PricingEditSheet({required this.car, required this.onSaved});

  @override
  State<_PricingEditSheet> createState() => _PricingEditSheetState();
}

class _PricingEditSheetState extends State<_PricingEditSheet> {
  static const _fields = <(String, String)>[
    ('initial_fee', 'Initial fee (one-way)'),
    ('initial_fee_return', 'Initial fee (return)'),
    ('per_km', 'Per kilometer'),
    ('per_km_return', 'Per kilometer (return)'),
    ('per_hour', 'Per hour'),
    ('per_extra_hour', 'Per extra time (hour)'),
    ('per_waypoint', 'Per waypoint'),
    ('per_waypoint_duration_per_min', 'Per waypoint minute'),
  ];

  final Map<String, TextEditingController> _ctrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pricing =
        (widget.car['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final (key, _) in _fields) {
      final value = (pricing[key] as num?)?.toDouble() ?? 0.0;
      _ctrls[key] = TextEditingController(text: value.toString());
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final pricing = <String, dynamic>{'currency': 'EUR'};
    for (final (key, label) in _fields) {
      final parsed = double.tryParse(_ctrls[key]!.text.replaceAll(',', '.'));
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Invalid value for "$label"'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
      pricing[key] = parsed;
    }

    setState(() => _saving = true);
    try {
      final carId = widget.car['id']?.toString() ?? '';
      await TransportApiClient.instance.put('/cars/$carId', {
        'pricing': pricing,
        // Keep the legacy sort/display field in sync with the initial fee.
        'base_price': pricing['initial_fee'],
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Save failed: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.car['name']?.toString() ?? 'Vehicle',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pricing parameters (EUR)',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final (key, label) in _fields)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: _ctrls[key],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.,]')),
                        ],
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: label,
                          labelStyle: TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                          filled: true,
                          fillColor: AppColors.surfaceElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: const Color(0xFF221A08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Text('Save pricing',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
