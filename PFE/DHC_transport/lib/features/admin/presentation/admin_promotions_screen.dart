import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/language_service.dart';
import '../../../core/services/transport_api_client.dart';
import '../../../shared/widgets/admin/admin_card.dart';
import '../../../shared/widgets/admin/admin_top_bar.dart';

class AdminPromotionsScreen extends StatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  State<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends State<AdminPromotionsScreen> {
  List<Map<String, dynamic>> _promos = [];
  Map<String, dynamic>? _loyalty;
  String _scope = 'all';
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
      // The loyalty summary is supporting context — a failure there must not
      // blank the promo list, so it is fetched separately and tolerated.
      Map<String, dynamic>? loyalty;
      try {
        loyalty = await TransportApiClient.instance.get('/promotions/loyalty');
      } catch (_) {
        loyalty = null;
      }
      if (!mounted) return;
      setState(() {
        _promos =
            ((res['promotions'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loyalty = loyalty;
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

  /// Codes matching the selected scope. 'campaign' = global marketing codes the
  /// admin creates; 'member' = tier/welcome/referral codes the loyalty
  /// programme mints for one client.
  List<Map<String, dynamic>> get _visible => switch (_scope) {
        'campaign' => _promos.where((p) => p['scope'] != 'member').toList(),
        'member' => _promos.where((p) => p['scope'] == 'member').toList(),
        _ => _promos,
      };

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
    AppColors.setDarkMode(Theme.of(context).brightness == Brightness.dark);
    final l = LanguageService.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AdminTopBar(
            title: l.t('admin_qa_promotions'),
            showBack: true,
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.secondary,
              backgroundColor: AppColors.surface,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
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
            else ...[
              if (_loyalty != null) ...[
                _LoyaltySummary(data: _loyalty!),
                const SizedBox(height: 18),
              ],
              _ScopeTabs(
                scope: _scope,
                campaignCount:
                    _promos.where((p) => p['scope'] != 'member').length,
                memberCount:
                    _promos.where((p) => p['scope'] == 'member').length,
                onChanged: (s) => setState(() => _scope = s),
              ),
              const SizedBox(height: 16),
              if (_visible.isEmpty)
                _EmptyView(
                  icon: Icons.local_offer_outlined,
                  message: _scope == 'member'
                      ? l.t('admin_no_member_codes')
                      : l.t('admin_no_promos'),
                )
              else
                for (final promo in _visible) ...[
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loyalty summary ──────────────────────────────────────────────────────────

/// Programme-wide loyalty state. Points here are derived by the same rule the
/// client app uses (completed trips x 10), so admin and client can never
/// disagree about a member's tier.
class _LoyaltySummary extends StatelessWidget {
  final Map<String, dynamic> data;

  const _LoyaltySummary({required this.data});

  static const _tierColours = {
    'Bronze': Color(0xFFB08D57),
    'Silver': Color(0xFFA8A9AD),
    'Gold': Color(0xFFC8A96B),
    'Black': Color(0xFF6E6E73),
  };

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final tiers = (data['tiers'] as Map?)?.cast<String, dynamic>() ?? const {};
    final members = (data['total_members'] as num?)?.toInt() ?? 0;
    final referred = (data['referred_signups'] as num?)?.toInt() ?? 0;
    final pending = (data['pending_referrals'] as num?)?.toInt() ?? 0;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: AppColors.secondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.t('admin_loyalty_programme'),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                l.t('admin_loyalty_members', args: {'n': '$members'}),
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in tiers.entries)
                _TierPill(
                  tier: entry.key,
                  count: (entry.value as num?)?.toInt() ?? 0,
                  colour: _tierColours[entry.key] ?? AppColors.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppColors.surfaceElevated, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: l.t('admin_loyalty_referred'),
                  value: '$referred',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: l.t('admin_loyalty_pending'),
                  value: '$pending',
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: l.t('admin_loyalty_member_codes'),
                  value: '${(data['member_codes'] as num?)?.toInt() ?? 0}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierPill extends StatelessWidget {
  final String tier;
  final int count;
  final Color colour;

  const _TierPill(
      {required this.tier, required this.count, required this.colour});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colour.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: colour),
          ),
          const SizedBox(width: 7),
          Text(
            '$tier  $count',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 2,
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

// ─── Scope tabs ───────────────────────────────────────────────────────────────

class _ScopeTabs extends StatelessWidget {
  final String scope;
  final int campaignCount;
  final int memberCount;
  final ValueChanged<String> onChanged;

  const _ScopeTabs({
    required this.scope,
    required this.campaignCount,
    required this.memberCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final tabs = [
      ('all', l.t('admin_scope_all'), campaignCount + memberCount),
      ('campaign', l.t('admin_scope_campaign'), campaignCount),
      ('member', l.t('admin_scope_member'), memberCount),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (value, label, count) = tabs[i];
          final selected = value == scope;
          return GestureDetector(
            onTap: () => onChanged(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    selected ? AppColors.secondary : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$label ($count)',
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF141313)
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
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
    final l = LanguageService.instance;
    final active = promo['active'] == true;
    final discountType = promo['discount_type']?.toString() ?? 'percentage';
    final value = promo['value'];
    final valueLabel = discountType == 'percentage'
        ? '${value?.toString() ?? '0'}%'
        : '${value?.toString() ?? '0'} EUR';
    final usageCount = promo['usage_count'] ?? 0;
    final usageLimit = promo['usage_limit'] ?? 0;
    // Member codes are minted by the loyalty programme for one client. Editing
    // one would desync it from the tier that issued it, so the backend refuses
    // — the card hides Edit rather than offering an action that will fail.
    final isMember = promo['scope'] == 'member';
    final owner = promo['owner_name']?.toString();
    final origin = promo['origin']?.toString() ?? 'campaign';
    final expiry = promo['expiry_date']?.toString();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Generated codes (BRONZE2623-YTJ4, WELCOME10-A6Q5) are long
              // enough to push the actions off-screen — let the chip shrink.
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    promo['code']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
              if (!isMember)
                IconButton(
                  icon: Icon(Icons.edit_rounded,
                      color: AppColors.textSecondary, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 18),
                onPressed: onDelete,
                tooltip: isMember ? 'Revoke' : 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          // Who this private code belongs to, and what issued it — without
          // this the admin just sees an unexplained BRONZE2623-YTJ4.
          if (isMember) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _OriginBadge(origin: origin),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    owner == null || owner.isEmpty
                        ? l.t('admin_member_code')
                        : owner,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Wrap, not Row: the expiry chip is wide and would otherwise
          // overflow beside the usage chip on a narrow phone.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.bar_chart_rounded,
                label: '$usageCount / $usageLimit uses',
              ),
              if (expiry != null)
                _InfoChip(
                  icon: Icons.calendar_today_rounded,
                  label: 'Expires ${_formatExpiry(expiry)}',
                ),
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

  /// The API returns a full ISO timestamp ('2026-10-30T18:31:16.123+00:00');
  /// only the date is useful on a card, and the rest overflows.
  static String _formatExpiry(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return DateFormat('d MMM yyyy').format(parsed.toLocal());
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }
}

/// What minted a member code: a loyalty tier, a referral payout, or signup.
class _OriginBadge extends StatelessWidget {
  final String origin;

  const _OriginBadge({required this.origin});

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final (label, colour, icon) = switch (origin) {
      'tier' => (
          l.t('admin_origin_tier'),
          const Color(0xFFC8A96B),
          Icons.workspace_premium_rounded
        ),
      'referral' => (
          l.t('admin_origin_referral'),
          const Color(0xFF00A896),
          Icons.group_add_rounded
        ),
      'welcome' => (
          l.t('admin_origin_welcome'),
          const Color(0xFF4A90D9),
          Icons.waving_hand_rounded
        ),
      _ => (
          l.t('admin_origin_campaign'),
          AppColors.textMuted,
          Icons.campaign_rounded
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colour),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colour,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
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
