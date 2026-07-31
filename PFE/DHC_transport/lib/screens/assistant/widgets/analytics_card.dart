import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../chat_message_model.dart';

/// Rich business-intelligence bubble for the admin AVA chat.
///
/// Renders the payload of the backend's "analytics" SSE event:
///   KPI row (horizontal metric tiles) → narrative → charts (fl_chart:
///   line/area/bar/pie from spec dicts) → insight bullets.
///
/// Visually distinct from text bubbles: darker surface, subtle gold top
/// border — signalling "data response".
const _gold = Color(0xFFC8A96B);
const _goldDeep = Color(0xFF8E7745);
const _surface = Color(0xFF121110);
const _surfaceTile = Color(0xFF1B1916);
const _text = Color(0xFFE9E1DA);
const _textMuted = Color(0xFF998F81);
const _green = Color(0xFF27AE60);
const _red = Color(0xFFE05B4B);

const _mixedPalette = <Color>[
  _gold,
  Color(0xFF4A90D9),
  Color(0xFF00A896),
  Color(0xFF7B5EA7),
  Color(0xFFD9534F),
  Color(0xFF27AE60),
];

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, right: 12),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          // Uniform border only — a rounded border with a differently
          // coloured top side is a Flutter paint assertion. The gold
          // "data response" accent is the clipped bar below instead.
          border: Border.all(color: const Color(0x22C8A96B)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 2.5, color: _gold), // gold top accent
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: _body(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final kpis = _listOf('kpis');
    final charts = _listOf('charts');
    final insights = ((_data['insights'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.insights_rounded, color: _gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _titleFor(_data['analysis_type']?.toString()),
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Text(
                  message.timeLabel,
                  style: const TextStyle(color: _textMuted, fontSize: 10),
                ),
              ],
            ),

            // KPI row
            if (kpis.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kpis.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _KpiTile(kpi: kpis[i]),
                ),
              ),
            ],

            // Narrative
            if (message.text.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                message.text.trim(),
                style: const TextStyle(
                  color: _text,
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),
            ],

            // Charts
            for (final chart in charts) ...[
              const SizedBox(height: 18),
              _ChartBlock(spec: chart),
            ],

            // Insights
            if (insights.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'KEY INSIGHTS',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              for (final insight in insights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          insight,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        );
  }

  static String _titleFor(String? type) => switch (type) {
        'revenue' => 'REVENUE ANALYSIS',
        'seasonal' => 'SEASONAL ANALYSIS',
        'pricing_impact' => 'PRICING IMPACT ANALYSIS',
        'vehicles' => 'VEHICLE PERFORMANCE',
        _ => 'BUSINESS REVIEW',
      };
}

// ─── KPI tile ───────────────────────────────────────────────────────────────

class _KpiTile extends StatelessWidget {
  final Map<String, dynamic> kpi;

  const _KpiTile({required this.kpi});

  @override
  Widget build(BuildContext context) {
    final trend = kpi['trend']?.toString();
    final positive = kpi['positive'] != false;
    return Container(
      width: 118,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceTile,
        borderRadius: BorderRadius.circular(12),
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
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kpi['value']?.toString() ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (trend != null && trend.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(
                  positive
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 11,
                  color: positive ? _green : _red,
                ),
                const SizedBox(width: 3),
                Text(
                  trend,
                  style: TextStyle(
                    color: positive ? _green : _red,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

  List<({String label, double value})> get _points =>
      ((spec['data'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => (
                label: e['label']?.toString() ?? '',
                value: (e['value'] as num?)?.toDouble() ?? 0.0,
              ))
          .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final points = _points;
    if (points.isEmpty) return const SizedBox.shrink();
    final type = spec['type']?.toString() ?? 'line';

    final chart = switch (type) {
      'pie' => _PieBlock(points: points),
      'bar' => _barChart(points),
      _ => _lineChart(points, isArea: type == 'area'),
    };
    final title = spec['title']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Charts are dense on a phone; expand gives them the full screen.
            GestureDetector(
              onTap: () => _openFullScreen(context, title, chart),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.open_in_full_rounded,
                    size: 15, color: _gold.withValues(alpha: 0.8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          width: double.infinity,
          child: chart,
        ),
      ],
    );
  }

  void _openFullScreen(BuildContext context, String title, Widget chart) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: _surface,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _textMuted),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 18, 24),
                  child: chart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show at most ~4 x-axis labels so they never overlap.
  Widget _bottomLabel(List<({String label, double value})> points, double v) {
    final i = v.round();
    if (i < 0 || i >= points.length) return const SizedBox.shrink();
    final step = (points.length / 4).ceil().clamp(1, 100);
    if (i % step != 0 && i != points.length - 1) {
      return const SizedBox.shrink();
    }
    var label = points[i].label;
    if (label.length > 9) label = label.substring(0, 9);
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(label,
          style: const TextStyle(color: _textMuted, fontSize: 9)),
    );
  }

  FlTitlesData _titles(List<({String label, double value})> points) =>
      FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (v, _) => Text(
              v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
              style: const TextStyle(color: _textMuted, fontSize: 9),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: 1,
            getTitlesWidget: (v, _) => _bottomLabel(points, v),
          ),
        ),
      );

  FlGridData get _grid => FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: Color(0x14FFFFFF), strokeWidth: 1),
      );

  Widget _lineChart(List<({String label, double value})> points,
      {required bool isArea}) {
    final highlight = spec['highlight']?.toString();
    final blue = spec['color_scheme'] == 'blue';
    final lineColor = blue ? const Color(0xFF4A90D9) : _gold;
    return LineChart(
      LineChartData(
        gridData: _grid,
        titlesData: _titles(points),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${points[s.x.toInt()].label}\n${s.y.toStringAsFixed(0)}',
                      const TextStyle(
                          color: _text,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < points.length; i++)
                FlSpot(i.toDouble(), points[i].value),
            ],
            isCurved: true,
            curveSmoothness: 0.3,
            color: lineColor,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, _) =>
                  highlight != null &&
                  points[spot.x.toInt()].label == highlight,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: lineColor,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: isArea ? 0.22 : 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barChart(List<({String label, double value})> points) {
    final mixed = spec['color_scheme'] == 'mixed';
    return BarChart(
      BarChartData(
        gridData: _grid,
        titlesData: _titles(points),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${points[group.x].label}\n${rod.toY.toStringAsFixed(0)}',
              const TextStyle(
                  color: _text, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: points[i].value,
                width: (220 / points.length).clamp(6.0, 22.0),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4)),
                color: mixed
                    ? _mixedPalette[i % _mixedPalette.length]
                    : (i.isEven ? _gold : _goldDeep),
              ),
            ]),
        ],
      ),
    );
  }
}

class _PieBlock extends StatelessWidget {
  final List<({String label, double value})> points;

  const _PieBlock({required this.points});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 38,
              sections: [
                for (var i = 0; i < points.length; i++)
                  PieChartSectionData(
                    value: points[i].value <= 0 ? 0.01 : points[i].value,
                    color: _mixedPalette[i % _mixedPalette.length],
                    radius: i == 0 ? 56 : 48,
                    title: '${points[i].value.toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Legend
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < points.length && i < 6; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _mixedPalette[i % _mixedPalette.length],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          points[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _text, fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
