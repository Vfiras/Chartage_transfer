import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/transport_api_client.dart';
import '../../../shared/widgets/admin/admin_card.dart';

class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // General
  late TextEditingController _minHoursCtrl;
  late TextEditingController _modLimitCtrl;
  late TextEditingController _cancelLimitCtrl;

  // Night pricing
  bool _nightEnabled = true;
  late TextEditingController _nightStartCtrl;
  late TextEditingController _nightEndCtrl;
  late TextEditingController _nightPctCtrl;

  // Last-minute pricing
  bool _lastMinuteEnabled = true;
  late TextEditingController _lastMinuteHoursCtrl;
  late TextEditingController _lastMinutePctCtrl;

  // Weekend pricing
  bool _weekendEnabled = true;
  late TextEditingController _weekendPctCtrl;

  // Seasonal pricing
  bool _seasonalEnabled = false;
  late TextEditingController _seasonalPctCtrl;

  @override
  void initState() {
    super.initState();
    _minHoursCtrl = TextEditingController();
    _modLimitCtrl = TextEditingController();
    _cancelLimitCtrl = TextEditingController();
    _nightStartCtrl = TextEditingController();
    _nightEndCtrl = TextEditingController();
    _nightPctCtrl = TextEditingController();
    _lastMinuteHoursCtrl = TextEditingController();
    _lastMinutePctCtrl = TextEditingController();
    _weekendPctCtrl = TextEditingController();
    _seasonalPctCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _minHoursCtrl.dispose();
    _modLimitCtrl.dispose();
    _cancelLimitCtrl.dispose();
    _nightStartCtrl.dispose();
    _nightEndCtrl.dispose();
    _nightPctCtrl.dispose();
    _lastMinuteHoursCtrl.dispose();
    _lastMinutePctCtrl.dispose();
    _weekendPctCtrl.dispose();
    _seasonalPctCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await TransportApiClient.instance.get('/pricing/config');
      if (!mounted) return;
      final c = (res['pricing_config'] as Map?)?.cast<String, dynamic>() ?? {};
      _applyConfig(c);
      setState(() {
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

  void _applyConfig(Map<String, dynamic> c) {
    _minHoursCtrl.text = c['minimum_booking_hours']?.toString() ?? '3';
    _modLimitCtrl.text = c['modification_limit_hours']?.toString() ?? '24';
    _cancelLimitCtrl.text = c['cancellation_limit_hours']?.toString() ?? '24';

    final night = (c['night_pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    _nightEnabled = night['enabled'] == true;
    _nightStartCtrl.text = night['start_time']?.toString() ?? '22:00';
    _nightEndCtrl.text = night['end_time']?.toString() ?? '06:00';
    _nightPctCtrl.text = night['percentage']?.toString() ?? '30';

    final lm =
        (c['last_minute_pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    _lastMinuteEnabled = lm['enabled'] == true;
    _lastMinuteHoursCtrl.text = lm['within_hours']?.toString() ?? '24';
    _lastMinutePctCtrl.text = lm['percentage']?.toString() ?? '20';

    final wk = (c['weekend_pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    _weekendEnabled = wk['enabled'] == true;
    _weekendPctCtrl.text = wk['percentage']?.toString() ?? '10';

    final se = (c['seasonal_pricing'] as Map?)?.cast<String, dynamic>() ?? {};
    _seasonalEnabled = se['enabled'] == true;
    _seasonalPctCtrl.text = se['percentage']?.toString() ?? '0';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = {
        'minimum_booking_hours': int.tryParse(_minHoursCtrl.text.trim()) ?? 3,
        'modification_limit_hours':
            int.tryParse(_modLimitCtrl.text.trim()) ?? 24,
        'cancellation_limit_hours':
            int.tryParse(_cancelLimitCtrl.text.trim()) ?? 24,
        'night_pricing': {
          'enabled': _nightEnabled,
          'start_time': _nightStartCtrl.text.trim(),
          'end_time': _nightEndCtrl.text.trim(),
          'percentage': double.tryParse(_nightPctCtrl.text.trim()) ?? 30,
        },
        'last_minute_pricing': {
          'enabled': _lastMinuteEnabled,
          'within_hours': int.tryParse(_lastMinuteHoursCtrl.text.trim()) ?? 24,
          'percentage': double.tryParse(_lastMinutePctCtrl.text.trim()) ?? 20,
        },
        'weekend_pricing': {
          'enabled': _weekendEnabled,
          'percentage': double.tryParse(_weekendPctCtrl.text.trim()) ?? 10,
        },
        'seasonal_pricing': {
          'enabled': _seasonalEnabled,
          'percentage': double.tryParse(_seasonalPctCtrl.text.trim()) ?? 0,
        },
      };
      await TransportApiClient.instance.put('/pricing/rules', payload);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pricing rules saved'),
          backgroundColor: Color(0xFF55A86B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Pricing Rules',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _saving
                  ? Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: AppColors.secondary, strokeWidth: 2.5),
                      ),
                    )
                  : TextButton(
                      onPressed: _save,
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.secondary))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded,
                            color: AppColors.textMuted, size: 40),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 14)),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _load, child: Text('Retry')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      _SectionHeader('General limits'),
                      const SizedBox(height: 12),
                      AdminCard(
                        child: Column(
                          children: [
                            _IntField(
                              controller: _minHoursCtrl,
                              label: 'Minimum booking lead time (hours)',
                            ),
                            const SizedBox(height: 12),
                            _IntField(
                              controller: _modLimitCtrl,
                              label: 'Modification deadline (hours before)',
                            ),
                            const SizedBox(height: 12),
                            _IntField(
                              controller: _cancelLimitCtrl,
                              label: 'Cancellation deadline (hours before)',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionHeader('Night pricing'),
                      const SizedBox(height: 12),
                      AdminCard(
                        child: Column(
                          children: [
                            _ToggleRow(
                              label: 'Enable night surcharge',
                              value: _nightEnabled,
                              onChanged: (v) =>
                                  setState(() => _nightEnabled = v),
                            ),
                            if (_nightEnabled) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _TimeField(
                                      controller: _nightStartCtrl,
                                      label: 'Start (HH:MM)',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _TimeField(
                                      controller: _nightEndCtrl,
                                      label: 'End (HH:MM)',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _PctField(
                                      controller: _nightPctCtrl,
                                      label: 'Surcharge %',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionHeader('Last-minute pricing'),
                      const SizedBox(height: 12),
                      AdminCard(
                        child: Column(
                          children: [
                            _ToggleRow(
                              label: 'Enable last-minute surcharge',
                              value: _lastMinuteEnabled,
                              onChanged: (v) =>
                                  setState(() => _lastMinuteEnabled = v),
                            ),
                            if (_lastMinuteEnabled) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _IntField(
                                      controller: _lastMinuteHoursCtrl,
                                      label: 'Within hours',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _PctField(
                                      controller: _lastMinutePctCtrl,
                                      label: 'Surcharge %',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionHeader('Weekend pricing'),
                      const SizedBox(height: 12),
                      AdminCard(
                        child: Column(
                          children: [
                            _ToggleRow(
                              label: 'Enable weekend surcharge',
                              value: _weekendEnabled,
                              onChanged: (v) =>
                                  setState(() => _weekendEnabled = v),
                            ),
                            if (_weekendEnabled) ...[
                              const SizedBox(height: 12),
                              _PctField(
                                controller: _weekendPctCtrl,
                                label: 'Surcharge %',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SectionHeader('Seasonal pricing'),
                      const SizedBox(height: 12),
                      AdminCard(
                        child: Column(
                          children: [
                            _ToggleRow(
                              label: 'Enable seasonal demand pricing',
                              value: _seasonalEnabled,
                              onChanged: (v) =>
                                  setState(() => _seasonalEnabled = v),
                            ),
                            if (_seasonalEnabled) ...[
                              const SizedBox(height: 12),
                              _PctField(
                                controller: _seasonalPctCtrl,
                                label: 'Surcharge %',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
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
                                'Save pricing rules',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ─── Subwidgets ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.secondary,
          activeTrackColor: AppColors.secondary.withValues(alpha: 0.4),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _IntField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _IntField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _PctField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _PctField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(labelText: label, suffixText: '%'),
    );
  }
}

class _TimeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _TimeField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.datetime,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(labelText: label),
    );
  }
}
