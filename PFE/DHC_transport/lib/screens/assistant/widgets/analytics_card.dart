import 'package:flutter/material.dart';

import '../../../core/services/language_service.dart';
import '../../../shared/widgets/admin/admin_charts.dart';
import '../chat_message_model.dart';

/// Rich business-intelligence bubble for the admin AVA chat.
///
/// Renders the payload of the backend's "analytics" SSE event:
///   KPI tiles → structured narrative → charts → insight bullets.
///
/// The backend sends only the charts its analysis mode produced (a revenue
/// answer carries two, a full review five), so nothing here is hardcoded to a
/// chart count — whatever arrives is laid out in order.
///
/// Charts come from `shared/widgets/admin/admin_charts.dart`, the same
/// primitives the admin dashboard uses, so styling stays identical.

const _gold = Color(0xFFC8A96B);
const _surface = Color(0xFF1B1B1B); // AppColors.surfaceElevated
const _surfaceTile = Color(0xFF151515);
const _chartSurface = Color(0xFF141313);
const _hairline = Color(0x14FFFFFF);
const _text = Color(0xFFE9E1DA);
const _textMuted = Color(0xFF998F81);
const _green = Color(0xFF00A896);
const _red = Color(0xFFE05B4B);

class AnalyticsCard extends StatelessWidget {
  final ChatMessage message;

  const AnalyticsCard({super.key, required this.message});

  Map<String, dynamic> get _data => message.analyticsData ?? const {};

  List<Map<String, dynamic>> _listOf(String key) =>
      ((_data[key] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final l = LanguageService.instance;
    final kpis = _listOf('kpis');
    final charts = _listOf('charts');
    final insights = ((_data['insights'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    final narrative = _Narrative.parse(message.text);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18, right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            // Uniform border only — a rounded border with a differently
            // coloured top side is a Flutter paint assertion. The gold
            // accent is the 3px sliver below instead.
            border: Border.all(color: const Color(0x22C8A96B)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 3, color: _gold), // gold top accent
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    if (kpis.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _kpiRow(kpis),
                    ],
                    if (!narrative.isEmpty) ...[
                      const SizedBox(height: 14),
                      _narrativeBlock(l, narrative),
                    ],
                    for (final chart in charts) ...[
                      const SizedBox(height: 12),
                      _ChartBlock(spec: chart),
                    ],
                    if (insights.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _insightsBlock(l, insights),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header: ✦ TITLE … time ─────────────────────────────────────────────────
  Widget _header() {
    final title = (_data['title']?.toString().toUpperCase() ??
        _titleFor(_data['mode']?.toString() ?? _data['analysis_type']?.toString()));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: _gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Text(message.timeLabel,
                  style: const TextStyle(color: _textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: _hairline),
        ],
      ),
    );
  }

  // ── KPI tiles (horizontal scroll when they overflow) ──────────────────────
  Widget _kpiRow(List<Map<String, dynamic>> kpis) => SizedBox(
        // Tall enough for label + 18px value + trend row; the trend row is
        // optional, so tiles without one just centre their content.
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: kpis.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => _KpiTile(kpi: kpis[i]),
        ),
      );

  // ── Narrative: Summary / Key findings / Recommendation ────────────────────
  Widget _narrativeBlock(LanguageService l, _Narrative n) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (n.summary.isNotEmpty)
            Text(
              n.summary,
              style: const TextStyle(
                color: _gold,
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (n.findings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l.t('ava_key_findings'),
              style: const TextStyle(
                color: _textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 7),
            for (final f in n.findings) _bullet(f, dense: true),
          ],
          if (n.recommendation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${l.t('ava_recommendation')} ',
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    TextSpan(
                      text: n.recommendation,
                      style: TextStyle(
                        color: _text.withValues(alpha: 0.80),
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Prose that didn't follow the structured format still renders.
          if (n.body.isNotEmpty)
            Text(
              n.body,
              style: const TextStyle(color: _text, fontSize: 13, height: 1.5),
            ),
        ],
      );

  Widget _insightsBlock(LanguageService l, List<String> insights) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('ava_key_insights'),
              style: const TextStyle(
                color: _gold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 9),
            for (final i in insights.take(5)) _bullet(i),
          ],
        ),
      );

  static Widget _bullet(String text, {bool dense = false}) => Padding(
        padding: EdgeInsets.only(bottom: dense ? 6 : 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _gold,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: _text.withValues(alpha: 0.92),
                  fontSize: dense ? 13 : 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );

  static String _titleFor(String? mode) => switch (mode) {
        'revenue' => 'REVENUE ANALYSIS',
        'bookings' => 'BOOKING TRENDS',
        'seasonal' => 'SEASONAL PATTERNS',
        // 'pricing_impact' is the pre-mode name; still sent by older sessions.
        'pricing' || 'pricing_impact' => 'PRICING IMPACT',
        'vehicles' => 'FLEET PERFORMANCE',
        _ => 'BUSINESS REVIEW',
      };
}

// ─── Narrative parsing ──────────────────────────────────────────────────────

/// Splits the backend's "Summary: … / Key findings: • … / Recommendation: …"
/// narrative into its parts. Anything that doesn't match the shape (an older
/// session, or a model that ignored the format) lands in [body] and still
/// renders as plain prose — the card never drops text.
class _Narrative {
  final String summary;
  final List<String> findings;
  final String recommendation;
  final String body;

  const _Narrative({
    this.summary = '',
    this.findings = const [],
    this.recommendation = '',
    this.body = '',
  });

  bool get isEmpty =>
      summary.isEmpty &&
      findings.isEmpty &&
      recommendation.isEmpty &&
      body.isEmpty;

  static final _summaryRe =
      RegExp(r'^\s*summary\s*:\s*(.+)$', caseSensitive: false);
  static final _findingsRe =
      RegExp(r'^\s*key findings\s*:\s*(.*)$', caseSensitive: false);
  static final _recRe =
      RegExp(r'^\s*recommendations?\s*:\s*(.+)$', caseSensitive: false);
  static final _bulletRe = RegExp(r'^\s*[•\-\*]\s*(.+)$');

  static _Narrative parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const _Narrative();

    var summary = '';
    var recommendation = '';
    final findings = <String>[];
    final leftovers = <String>[];
    var section = _Section.none;

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final s = _summaryRe.firstMatch(trimmed);
      if (s != null) {
        summary = _clean(s.group(1)!);
        section = _Section.summary;
        continue;
      }
      final f = _findingsRe.firstMatch(trimmed);
      if (f != null) {
        final inline = _clean(f.group(1)!);
        if (inline.isNotEmpty) findings.add(inline);
        section = _Section.findings;
        continue;
      }
      final r = _recRe.firstMatch(trimmed);
      if (r != null) {
        recommendation = _clean(r.group(1)!);
        section = _Section.recommendation;
        continue;
      }

      final b = _bulletRe.firstMatch(trimmed);
      if (b != null) {
        findings.add(_clean(b.group(1)!));
        continue;
      }

      // Continuation of whichever section we're in.
      switch (section) {
        case _Section.summary:
          summary = '$summary ${_clean(trimmed)}'.trim();
        case _Section.recommendation:
          recommendation = '$recommendation ${_clean(trimmed)}'.trim();
        case _Section.findings:
          findings.add(_clean(trimmed));
        case _Section.none:
          leftovers.add(_clean(trimmed));
      }
    }

    return _Narrative(
      summary: summary,
      findings: findings.where((f) => f.isNotEmpty).toList(growable: false),
      recommendation: recommendation,
      body: leftovers.join('\n\n'),
    );
  }

  /// Drops markdown emphasis the model occasionally emits despite the format
  /// instruction, so it never shows as literal asterisks.
  static String _clean(String s) =>
      s.replaceAll('**', '').replaceAll('##', '').trim();
}

enum _Section { none, summary, findings, recommendation }

// ─── KPI tile ───────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final Map<String, dynamic> kpi;

  const _KpiTile({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final trend = kpi['trend']?.toString();
    final positive = kpi['positive'] != false;
    final hasTrend = trend != null && trend.isNotEmpty;

    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _surfaceTile,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            (kpi['label']?.toString() ?? '').toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            kpi['value']?.toString() ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (hasTrend) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  positive
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  size: 14,
                  color: positive ? _green : _red,
                ),
                Expanded(
                  child: Text(
                    trend,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: positive ? _green : _red,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Chart block ────────────────────────────────────────────────────────────

class _ChartBlock extends StatelessWidget {
  final Map<String, dynamic> spec;

  const _ChartBlock({required this.spec});

  List<ChartPoint> get _points => ((spec['data'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => ChartPoint(
            e['label']?.toString() ?? '',
            (e['value'] as num?)?.toDouble() ?? 0.0,
          ))
      .toList(growable: false);

  bool get _isEuro => spec['unit']?.toString() == 'eur';

  Widget _chart({required bool expanded}) {
    final points = _points;
    return switch (spec['type']?.toString()) {
      'pie' => GoldPieChart(
          points: points,
          legend: expanded ? PieLegend.below : PieLegend.beside,
          holeColor: _chartSurface,
        ),
      'bar' => GoldBarChart(
          points: points,
          asEuro: _isEuro,
          // A paired before/after series reads better in two alternating
          // colours than as one gold run.
          colors: spec['color_scheme'] == 'paired'
              ? const [Color(0xFF4A90D9), _gold]
              : (spec['color_scheme'] == 'mixed' ? kChartPalette : null),
        ),
      'area' => GoldAreaChart(points: points),
      _ => GoldLineChart(
          points: points,
          asEuro: _isEuro,
          highlight: spec['highlight']?.toString(),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_points.isEmpty) return const SizedBox.shrink();
    final title = spec['title']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _chartSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Charts are dense on a phone; expand gives them the full width.
              GestureDetector(
                onTap: () => _openFullScreen(context, title),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.open_in_full_rounded,
                      size: 14, color: _gold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 165,
            width: double.infinity,
            child: _chart(expanded: false),
          ),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) => Dialog(
        backgroundColor: _surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: _textMuted, size: 20),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                width: double.infinity,
                child: _chart(expanded: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
