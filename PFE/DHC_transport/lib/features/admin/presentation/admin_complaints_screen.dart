import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/transport_api_client.dart';
import '../../../widgets/common/luxury_skeleton.dart';

/// Admin Complaints — full management screen.
///
/// Lists every complaint (newest first) with a status badge
/// (open / in_review / resolved). Tapping opens a detail sheet showing user,
/// booking reference, message, and timestamp, plus a status selector that
/// calls PATCH /complaints/{id}/status.
class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  List<Map<String, dynamic>> _complaints = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all | open | in_review | resolved

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
      final res = await TransportApiClient.instance.get('/complaints/');
      if (!mounted) return;
      setState(() {
        _complaints =
            ((res['complaints'] as List?) ?? []).cast<Map<String, dynamic>>();
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

  List<Map<String, dynamic>> get _visible => _filter == 'all'
      ? _complaints
      : _complaints
          .where((c) => (c['status'] ?? 'open') == _filter)
          .toList(growable: false);

  Future<void> _updateStatus(String id, String status) async {
    try {
      await TransportApiClient.instance.patch(
        '/complaints/$id/status',
        {'status': status},
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Update failed: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  void _openDetail(Map<String, dynamic> complaint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ComplaintDetailSheet(
        complaint: complaint,
        onStatusChanged: (status) {
          Navigator.of(context).pop();
          // Backend serializes Mongo docs with the raw `_id` key.
          final id = complaint['_id']?.toString() ??
              complaint['id']?.toString() ??
              '';
          _updateStatus(id, status);
        },
      ),
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
                      'Complaints',
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
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final f in const [
                    ('all', 'All'),
                    ('open', 'Open'),
                    ('in_review', 'In review'),
                    ('resolved', 'Resolved'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: _filter == f.$1,
                        onSelected: (_) => setState(() => _filter = f.$1),
                        selectedColor: AppColors.secondary,
                        backgroundColor: AppColors.surfaceElevated,
                        labelStyle: TextStyle(
                          color: _filter == f.$1
                              ? const Color(0xFF221A08)
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide.none,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      // Complaint-card-shaped skeletons instead of a spinner.
      return const SkeletonCardList(count: 5, cardHeight: 118);
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
    final items = _visible;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, color: AppColors.textMuted, size: 42),
            const SizedBox(height: 10),
            Text('No complaints here.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.secondary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ComplaintCard(
          complaint: items[i],
          onTap: () => _openDetail(items[i]),
        ),
      ),
    );
  }
}

// ─── Shared helpers ────────────────────────────────────────────────────────────

(Color, Color, String) _statusStyle(String status) {
  switch (status) {
    case 'resolved':
      return (AppColors.chipGreenBg, AppColors.green, 'RESOLVED');
    case 'in_review':
      return (AppColors.chipBlueBg, AppColors.blue, 'IN REVIEW');
    default:
      return (AppColors.chipPinkBg, AppColors.danger, 'OPEN');
  }
}

String _formatWhen(dynamic raw) {
  final parsed = DateTime.tryParse(raw?.toString() ?? '');
  if (parsed == null) return '';
  return DateFormat('MMM d, yyyy · HH:mm').format(parsed.toLocal());
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _statusStyle(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Map<String, dynamic> complaint;
  final VoidCallback onTap;

  const _ComplaintCard({required this.complaint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = complaint['status']?.toString() ?? 'open';
    final bookingId = complaint['booking_id']?.toString();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
                Icon(Icons.feedback_rounded,
                    size: 16, color: AppColors.accentText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    complaint['user_id']?.toString() ?? 'Client',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              complaint['message']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (bookingId != null && bookingId.isNotEmpty) ...[
                  Icon(Icons.receipt_long_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      bookingId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(Icons.schedule_rounded,
                    size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  _formatWhen(complaint['created_at']),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplaintDetailSheet extends StatelessWidget {
  final Map<String, dynamic> complaint;
  final ValueChanged<String> onStatusChanged;

  const _ComplaintDetailSheet({
    required this.complaint,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final status = complaint['status']?.toString() ?? 'open';
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Complaint detail',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 18),
          _DetailRow(label: 'Client', value: complaint['user_id']?.toString()),
          _DetailRow(
              label: 'Booking', value: complaint['booking_id']?.toString()),
          _DetailRow(
              label: 'Submitted',
              value: _formatWhen(complaint['created_at'])),
          const SizedBox(height: 12),
          Text('MESSAGE',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              complaint['message']?.toString() ?? '',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          Text('UPDATE STATUS',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final s in const [
                ('open', 'Open'),
                ('in_review', 'In review'),
                ('resolved', 'Resolved'),
              ]) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: s.$1 == status ? null : () => onStatusChanged(s.$1),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.$1 == status
                            ? AppColors.secondary
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        s.$2,
                        style: TextStyle(
                          color: s.$1 == status
                              ? const Color(0xFF221A08)
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                if (s.$1 != 'resolved') const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const _DetailRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(value!,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
