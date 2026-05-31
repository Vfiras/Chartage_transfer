import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/transport_api_client.dart';
import '../../../shared/widgets/admin/admin_card.dart';

class AdminPromotionsScreen extends StatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  State<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends State<AdminPromotionsScreen> {
  List<Map<String, dynamic>> _promos = [];
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
      final res = await TransportApiClient.instance.get('/promotions/');
      if (!mounted) return;
      setState(() {
        _promos =
            ((res['promotions'] as List?) ?? []).cast<Map<String, dynamic>>();
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

  Future<void> _toggle(String id) async {
    try {
      await TransportApiClient.instance.patch('/promotions/$id/toggle', {});
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _delete(String id, String code) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete promotion'),
            content: Text('Remove promo code "$code"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444)),
                child: Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      await TransportApiClient.instance.delete('/promotions/$id');
      await _load();
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message), backgroundColor: const Color(0xFFEF4444)),
    );
  }

  void _openForm({Map<String, dynamic>? promo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PromoFormSheet(promo: promo, onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        'Promotions',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage promo codes and discounts',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                _GoldButton(
                  label: 'Add promo',
                  icon: Icons.add_rounded,
                  onTap: () => _openForm(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.secondary)),
              )
            else if (_error != null)
              _ErrorView(message: _error!, onRetry: _load)
            else if (_promos.isEmpty)
              const _EmptyView(
                icon: Icons.local_offer_outlined,
                message: 'No promotions yet.',
              )
            else
              for (final promo in _promos) ...[
                _PromoCard(
                  promo: promo,
                  onEdit: () => _openForm(promo: promo),
                  onToggle: () => _toggle(promo['_id']?.toString() ?? ''),
                  onDelete: () => _delete(
                    promo['_id']?.toString() ?? '',
                    promo['code']?.toString() ?? '',
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

// ─── Promo Card ───────────────────────────────────────────────────────────────

class _PromoCard extends StatelessWidget {
  final Map<String, dynamic> promo;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _PromoCard({
    required this.promo,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final active = promo['active'] == true;
    final discountType = promo['discount_type']?.toString() ?? 'percentage';
    final value = promo['value'];
    final valueLabel = discountType == 'percentage'
        ? '${value?.toString() ?? '0'}%'
        : '${value?.toString() ?? '0'} DT';
    final usageCount = promo['usage_count'] ?? 0;
    final usageLimit = promo['usage_limit'] ?? 0;
    final expiry = promo['expiry_date']?.toString();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  promo['code']?.toString() ?? '',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  valueLabel,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.edit_rounded,
                    color: AppColors.textSecondary, size: 18),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 18),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(
                icon: Icons.bar_chart_rounded,
                label: '$usageCount / $usageLimit uses',
              ),
              if (expiry != null) ...[
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: 'Expires $expiry',
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: active,
                activeThumbColor: AppColors.secondary,
                activeTrackColor: AppColors.secondary.withValues(alpha: 0.4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (_) => onToggle(),
              ),
              const SizedBox(width: 4),
              Text(
                active ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: active ? const Color(0xFF55A86B) : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Promo Form Sheet ─────────────────────────────────────────────────────────

class _PromoFormSheet extends StatefulWidget {
  final Map<String, dynamic>? promo;
  final VoidCallback onSaved;

  const _PromoFormSheet({required this.promo, required this.onSaved});

  @override
  State<_PromoFormSheet> createState() => _PromoFormSheetState();
}

class _PromoFormSheetState extends State<_PromoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _limitCtrl;
  late final TextEditingController _expiryCtrl;
  String _discountType = 'percentage';
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.promo;
    _codeCtrl = TextEditingController(text: p?['code']?.toString() ?? '');
    _valueCtrl = TextEditingController(text: p?['value']?.toString() ?? '');
    _limitCtrl =
        TextEditingController(text: p?['usage_limit']?.toString() ?? '100');
    _expiryCtrl =
        TextEditingController(text: p?['expiry_date']?.toString() ?? '');
    _discountType = p?['discount_type']?.toString() ?? 'percentage';
    _active = p?['active'] != false;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _limitCtrl.dispose();
    _expiryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'code': _codeCtrl.text.trim().toUpperCase(),
        'discount_type': _discountType,
        'value': double.parse(_valueCtrl.text.trim()),
        'usage_limit': int.tryParse(_limitCtrl.text.trim()) ?? 100,
        'active': _active,
        if (_expiryCtrl.text.trim().isNotEmpty)
          'expiry_date': _expiryCtrl.text.trim(),
      };
      final id = widget.promo?['_id']?.toString();
      if (id != null) {
        await TransportApiClient.instance.put('/promotions/$id', payload);
      } else {
        await TransportApiClient.instance.post('/promotions/', payload);
      }
      if (mounted) Navigator.pop(context);
      widget.onSaved();
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
    final isEdit = widget.promo != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Edit promotion' : 'New promotion',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9a-z]'))
              ],
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(labelText: 'Promo code'),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _discountType,
                    dropdownColor: AppColors.surface,
                    style:
                        TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                          value: 'percentage', child: Text('Percentage')),
                      DropdownMenuItem(
                          value: 'fixed', child: Text('Fixed (DT)')),
                    ],
                    onChanged: (v) =>
                        setState(() => _discountType = v ?? _discountType),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _valueCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style:
                        TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(labelText: 'Value'),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _limitCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style:
                        TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(labelText: 'Usage limit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _expiryCtrl,
                    style:
                        TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    decoration:
                        InputDecoration(labelText: 'Expiry (YYYY-MM-DD)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: _active,
                  activeThumbColor: AppColors.secondary,
                  activeTrackColor: AppColors.secondary.withValues(alpha: 0.4),
                  onChanged: (v) => setState(() => _active = v),
                ),
                const SizedBox(width: 8),
                Text(
                  'Active',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                        isEdit ? 'Save changes' : 'Create promo',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
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

// ─── Shared ───────────────────────────────────────────────────────────────────

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

  const _GoldButton(
      {required this.label, required this.icon, required this.onTap});

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
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text('Retry')),
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
          Text(message,
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}
