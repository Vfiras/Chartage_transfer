import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/transport_api_client.dart';
import '../../../widgets/common/fallback_network_image.dart';
import '../../../widgets/common/luxury_skeleton.dart';

class AdminCarsScreen extends StatefulWidget {
  const AdminCarsScreen({super.key});

  @override
  State<AdminCarsScreen> createState() => _AdminCarsScreenState();
}

class _AdminCarsScreenState extends State<AdminCarsScreen> {
  List<Map<String, dynamic>> _cars = [];
  bool _loading = true;
  String? _error;

  /// The REAL fleet categories (see backend/app/db/fleet_data.py). The old
  /// list here was the legacy 4-bucket set (Standard/VIP/Luxury/Van), which
  /// made `DropdownButtonFormField` throw its "exactly one item with value"
  /// assertion — the fleet-edit red screen — for every real seeded vehicle.
  static const _categories = [
    'economy', 'comfort', 'minivan', 'van', 'minibus',
    'business', 'luxury', 'executive',
  ];

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

  Future<void> _toggleAvailability(String carId, bool current) async {
    try {
      await TransportApiClient.instance.patch(
        '/cars/$carId/availability',
        {},
        query: {'available': (!current).toString()},
      );
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _deleteCar(String carId, String carName) async {
    final confirmed = await _confirmDelete(carName);
    if (!confirmed) return;
    try {
      await TransportApiClient.instance.delete('/cars/$carId');
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<bool> _confirmDelete(String name) async {
    final l = LanguageService.instance;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(l.t('admin_delete_vehicle'),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
            content: Text(
              l.t('admin_delete_vehicle_confirm', args: {'name': name}),
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.t('cancel'),
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(l.t('delete')),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  void _openCarForm({Map<String, dynamic>? car}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _CarFormSheet(
        car: car,
        categories: _categories,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    final l = LanguageService.instance;
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.secondary,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.t('admin_fleet_title'),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.t('admin_fleet_subtitle'),
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                _GoldButton(
                  label: l.t('admin_add_car'),
                  icon: Icons.add_rounded,
                  onTap: () => _openCarForm(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const SkeletonCardList(
                count: 3,
                cardHeight: 230,
                padding: EdgeInsets.zero,
              )
            else if (_error != null)
              _ErrorView(message: _error!, onRetry: _load)
            else if (_cars.isEmpty)
              _EmptyView(
                icon: Icons.directions_car_outlined,
                message: l.t('admin_no_vehicles'),
              )
            else
              for (final car in _cars) ...[
                _CarCard(
                  car: car,
                  onEdit: () => _openCarForm(car: car),
                  onToggle: () => _toggleAvailability(
                    _carId(car),
                    car['availability'] == true,
                  ),
                  onDelete: () => _deleteCar(
                    _carId(car),
                    car['name']?.toString() ?? 'Vehicle',
                  ),
                ),
                const SizedBox(height: 14),
              ],
          ],
        ),
      ),
    );
  }
}

/// The API serializes Mongo docs with `_id`; some code paths add `id` too.
String _carId(Map<String, dynamic> car) =>
    (car['_id'] ?? car['id'])?.toString() ?? '';

// ─── Car Card ─────────────────────────────────────────────────────────────────

class _CarCard extends StatelessWidget {
  final Map<String, dynamic> car;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _CarCard({
    required this.car,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final available = car['availability'] == true;
    final category = car['category']?.toString() ?? '';
    final pricing = (car['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    final fromPrice = (pricing['initial_fee'] as num?)?.toDouble() ??
        (car['base_price'] as num?)?.toDouble() ??
        0;
    final imageUrl = car['image_url']?.toString() ?? '';

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image header + availability badge ─────────────────────────
          Stack(
            children: [
              _CarImage(url: imageUrl, height: 120),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: available
                        ? const Color(0xE61E3A1E)
                        : const Color(0xE63A1E1E),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    available ? l.t('admin_available') : l.t('admin_unavailable'),
                    style: TextStyle(
                      color: available
                          ? const Color(0xFF7BC98F)
                          : const Color(0xFFE08585),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car['name']?.toString() ?? '',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            car['model']?.toString() ?? '',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _InfoChip(
                        icon: Icons.people_rounded,
                        label: '${car['seats'] ?? 0}'),
                    const SizedBox(width: 8),
                    _InfoChip(
                        icon: Icons.luggage_rounded,
                        label: '${car['luggage'] ?? 0}'),
                    const Spacer(),
                    Text(
                      l.t('from_price'),
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${fromPrice.toStringAsFixed(2)} EUR',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Switch(
                            value: available,
                            activeThumbColor: AppColors.secondary,
                            activeTrackColor:
                                AppColors.secondary.withValues(alpha: 0.4),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (_) => onToggle(),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_rounded,
                          color: AppColors.textSecondary, size: 20),
                      onPressed: onEdit,
                      tooltip: l.t('admin_edit'),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 20),
                      onPressed: onDelete,
                      tooltip: l.t('delete'),
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

/// Vehicle image that renders bundled assets, network URLs, or a placeholder.
class _CarImage extends StatelessWidget {
  final String url;
  final double height;

  const _CarImage({required this.url, required this.height});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: height,
      width: double.infinity,
      color: AppColors.surfaceElevated,
      child: Icon(Icons.directions_car_rounded,
          color: AppColors.textMuted, size: 36),
    );
    if (url.isEmpty) return placeholder;
    if (url.startsWith('assets')) {
      return Container(
        height: height,
        width: double.infinity,
        color: Colors.white,
        child: Image.asset(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: FallbackNetworkImage(url: url, fit: BoxFit.cover),
    );
  }
}

// ─── Car Form Bottom Sheet ─────────────────────────────────────────────────────

class _CarFormSheet extends StatefulWidget {
  final Map<String, dynamic>? car;
  final List<String> categories;
  final VoidCallback onSaved;

  const _CarFormSheet({
    required this.car,
    required this.categories,
    required this.onSaved,
  });

  @override
  State<_CarFormSheet> createState() => _CarFormSheetState();
}

class _CarFormSheetState extends State<_CarFormSheet> {
  static const _pricingFields = <(String, String)>[
    ('initial_fee', 'admin_p_initial'),
    ('initial_fee_return', 'admin_p_initial_return'),
    ('per_km', 'admin_p_per_km'),
    ('per_km_return', 'admin_p_per_km_return'),
    ('per_hour', 'admin_p_per_hour'),
    ('per_extra_hour', 'admin_p_per_extra_hour'),
    ('per_waypoint', 'admin_p_per_waypoint'),
    ('per_waypoint_duration_per_min', 'admin_p_per_waypoint_min'),
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _seatsCtrl;
  late final TextEditingController _luggageCtrl;
  late final TextEditingController _imageCtrl;
  late final TextEditingController _featuresCtrl;
  final Map<String, TextEditingController> _pricingCtrls = {};
  late String _category;
  late bool _available;
  bool _saving = false;

  /// Dropdown items: the real categories PLUS whatever this car already has.
  /// A vehicle with a legacy or unknown category must never crash the form —
  /// its value is simply included so the Dropdown assertion holds.
  late final List<String> _categoryItems;

  @override
  void initState() {
    super.initState();
    final c = widget.car;
    _nameCtrl = TextEditingController(text: c?['name']?.toString() ?? '');
    _modelCtrl = TextEditingController(text: c?['model']?.toString() ?? '');
    _seatsCtrl = TextEditingController(text: c?['seats']?.toString() ?? '4');
    _luggageCtrl =
        TextEditingController(text: c?['luggage']?.toString() ?? '2');
    _imageCtrl =
        TextEditingController(text: c?['image_url']?.toString() ?? '');
    final features = (c?['features'] as List?)?.cast<dynamic>() ?? const [];
    _featuresCtrl =
        TextEditingController(text: features.map((f) => '$f').join(', '));

    _category = c?['category']?.toString() ?? widget.categories.first;
    _categoryItems = {
      ...widget.categories,
      if (_category.isNotEmpty) _category,
    }.toList();
    _available = c?['availability'] != false;

    final pricing = (c?['pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    for (final (key, _) in _pricingFields) {
      // Legacy cars without a pricing object start from base_price on the
      // initial fee so the quote engine keeps producing sane numbers.
      final fallback = key == 'initial_fee'
          ? (c?['base_price'] as num?)?.toDouble() ?? 0.0
          : 0.0;
      final value = (pricing[key] as num?)?.toDouble() ?? fallback;
      _pricingCtrls[key] = TextEditingController(text: value.toString());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    _seatsCtrl.dispose();
    _luggageCtrl.dispose();
    _imageCtrl.dispose();
    _featuresCtrl.dispose();
    for (final ctrl in _pricingCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l = LanguageService.instance;
    if (!_formKey.currentState!.validate()) return;

    final pricing = <String, dynamic>{'currency': 'EUR'};
    for (final (key, labelKey) in _pricingFields) {
      final parsed =
          double.tryParse(_pricingCtrls[key]!.text.replaceAll(',', '.'));
      if (parsed == null || parsed < 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${l.t('admin_invalid_value')}: ${l.t(labelKey)}'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
      pricing[key] = parsed;
    }

    final features = _featuresCtrl.text
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();

    setState(() => _saving = true);
    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'category': _category,
        'seats': int.parse(_seatsCtrl.text.trim()),
        'luggage': int.parse(_luggageCtrl.text.trim()),
        'availability': _available,
        'image_url': _imageCtrl.text.trim(),
        'features': features,
        'pricing': pricing,
        // Legacy sort/display field stays in sync with the initial fee,
        // matching what the admin Pricing screen does on save.
        'base_price': pricing['initial_fee'],
      };
      final id = widget.car == null ? null : _carId(widget.car!);
      if (id != null && id.isNotEmpty) {
        await TransportApiClient.instance.put('/cars/$id', payload);
      } else {
        await TransportApiClient.instance.post('/cars/', payload);
      }
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final isEdit = widget.car != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
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
              const SizedBox(height: 16),
              Text(
                isEdit ? l.t('admin_edit_vehicle') : l.t('admin_add_vehicle'),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),

              // ── Identity ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _nameCtrl,
                      label: l.t('admin_vehicle_name'),
                      validator: (v) => v == null || v.isEmpty
                          ? l.t('admin_required')
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _modelCtrl,
                      label: l.t('admin_vehicle_model'),
                      validator: (v) => v == null || v.isEmpty
                          ? l.t('admin_required')
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                dropdownColor: AppColors.surface,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration:
                    InputDecoration(labelText: l.t('admin_category')),
                items: _categoryItems
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _seatsCtrl,
                      label: l.t('admin_seats'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (v) => v == null || v.isEmpty
                          ? l.t('admin_required')
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _luggageCtrl,
                      label: l.t('admin_luggage'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (v) => v == null || v.isEmpty
                          ? l.t('admin_required')
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: _available,
                    activeThumbColor: AppColors.secondary,
                    activeTrackColor:
                        AppColors.secondary.withValues(alpha: 0.4),
                    onChanged: (v) => setState(() => _available = v),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.t('admin_available'),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // ── Image ────────────────────────────────────────────────
              const SizedBox(height: 8),
              _SectionLabel(l.t('admin_image_section')),
              const SizedBox(height: 8),
              _Field(
                controller: _imageCtrl,
                label: l.t('admin_image_url'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _CarImage(url: _imageCtrl.text.trim(), height: 110),
              ),

              // ── Pricing ──────────────────────────────────────────────
              const SizedBox(height: 18),
              _SectionLabel(l.t('admin_pricing_eur')),
              const SizedBox(height: 8),
              for (var i = 0; i < _pricingFields.length; i += 2) ...[
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: _pricingCtrls[_pricingFields[i].$1]!,
                        label: l.t(_pricingFields[i].$2),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: i + 1 < _pricingFields.length
                          ? _Field(
                              controller:
                                  _pricingCtrls[_pricingFields[i + 1].$1]!,
                              label: l.t(_pricingFields[i + 1].$2),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // ── Features ─────────────────────────────────────────────
              _SectionLabel(l.t('admin_features_section')),
              const SizedBox(height: 8),
              _Field(
                controller: _featuresCtrl,
                label: l.t('admin_features_hint'),
              ),

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          isEdit
                              ? l.t('save_changes')
                              : l.t('admin_add_vehicle'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
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

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: AppColors.secondary,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

// ─── Shared small widgets ──────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
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

class _GoldButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GoldButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.secondary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(LanguageService.instance.t('admin_retry')),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
