import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Shared chart primitives for the admin surface.
///
/// One styling source of truth for the dashboard AND for AVA's analytics card,
/// so a bar chart looks identical wherever it appears: gold rods with rounded
/// tops, horizontal-only gridlines, muted axis labels, gold-on-dark tooltips.
///
/// Every chart takes a plain `List<ChartPoint>` so callers never touch
/// fl_chart's spec objects directly.

class ChartPoint {
  final String label;
  final double value;

  const ChartPoint(this.label, this.value);
}

/// Categorical palette, ordered. Gold leads; teal / amber / blue follow.
const kChartPalette = <Color>[
  Color(0xFFC8A96B), // gold
  Color(0xFF00A896), // teal
  Color(0xFFE0C68A), // amber
  Color(0xFF4A90D9), // blue
  Color(0xFF7B5EA7), // violet
  Color(0xFF10B981), // green
];

const _gold = Color(0xFFC8A96B);

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

Color _gridLine(BuildContext c) => _isDark(c)
    ? Colors.white.withValues(alpha: 0.05)
    : Colors.black.withValues(alpha: 0.05);

TextStyle _axisStyle(BuildContext c) => TextStyle(
      color: AppColors.textMuted,
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    );

/// Gold pill tooltip with dark text — used by every touch-enabled chart.
BarTouchTooltipData _barTooltip(List<ChartPoint> points, bool asEuro) =>
    BarTouchTooltipData(
      getTooltipColor: (_) => _gold,
      tooltipRoundedRadius: 8,
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      getTooltipItem: (group, _, rod, __) {
        final label = group.x >= 0 && group.x < points.length
            ? points[group.x].label
            : '';
        return BarTooltipItem(
          '$label\n${_fmtValue(rod.toY, asEuro)}',
          const TextStyle(
            color: Color(0xFF141313),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        );
      },
    );

String _fmtValue(double v, bool asEuro) {
  final n =
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0);
  return asEuro ? '€$n' : n;
}

/// Show at most ~5 x-axis labels so they never collide on a phone.
Widget _bottomLabel(BuildContext c, List<ChartPoint> points, double v,
    String Function(String)? format) {
  final i = v.round();
  if (i < 0 || i >= points.length) return const SizedBox.shrink();
  final step = (points.length / 5).ceil().clamp(1, 100);
  if (i % step != 0 && i != points.length - 1) return const SizedBox.shrink();

  var label = format?.call(points[i].label) ?? points[i].label;
  if (label.length > 11) label = '${label.substring(0, 10)}…';
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(label, style: _axisStyle(c)),
  );
}

/// Gridline spacing, rounded up to a "nice" number (1, 2, 5, 10, 20, 50, …).
/// Never below 1, so small integer counts step in whole numbers instead of
/// 0.5s that all render as the same rounded label.
double _step(double rawMax) {
  final target = rawMax / 4;
  if (target <= 1) return 1;
  final magnitude = math.pow(10, (math.log(target) / math.ln10).floor())
      .toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0]) {
    if (target <= magnitude * m) return magnitude * m;
  }
  return magnitude * 10;
}

/// Chart ceiling: the first "nice" step at or above ~15% headroom, so the top
/// gridline carries a clean label and never collides with the value below it.
double _axisMax(double rawMax) {
  final step = _step(rawMax);
  return step * (rawMax * 1.15 / step).ceil();
}

FlTitlesData _titles(
  BuildContext context,
  List<ChartPoint> points, {
  required bool showLeftAxis,
  required bool asEuro,
  required double maxY,
  String Function(String)? labelFormat,
}) =>
    FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: showLeftAxis,
          reservedSize: asEuro ? 40 : 30,
          // Same step as the gridlines — otherwise fl_chart picks its own and
          // the axis shows repeated values next to unlabelled lines.
          interval: _step(maxY),
          getTitlesWidget: (v, _) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(_fmtValue(v, asEuro),
                textAlign: TextAlign.right, style: _axisStyle(context)),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: 1,
          getTitlesWidget: (v, _) =>
              _bottomLabel(context, points, v, labelFormat),
        ),
      ),
    );

FlGridData _grid(BuildContext context, double maxY) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: _step(maxY),
      getDrawingHorizontalLine: (_) =>
          FlLine(color: _gridLine(context), strokeWidth: 1),
    );

// ─── Bar ────────────────────────────────────────────────────────────────────

/// Gold bars with rounded tops, fading downward. Set [gradientBars] false for
/// flat gold, or supply [colors] for a categorical (per-bar) palette.
class GoldBarChart extends StatelessWidget {
  final List<ChartPoint> points;
  final bool showLeftAxis;
  final bool asEuro;
  final double? barWidth;
  final bool gradientBars;
  final List<Color>? colors;
  final String Function(String)? labelFormat;

  const GoldBarChart({
    super.key,
    required this.points,
    this.showLeftAxis = true,
    this.asEuro = false,
    this.barWidth,
    this.gradientBars = true,
    this.colors,
    this.labelFormat,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxY = points.fold<double>(1, (m, p) => p.value > m ? p.value : m);
    final width = barWidth ?? (230 / points.length).clamp(7.0, 20.0);

    // Top padding: the highest left-axis label is centred on its gridline and
    // would be clipped by the chart's own bounds without it.
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _axisMax(maxY),
          borderData: FlBorderData(show: false),
          gridData: _grid(context, maxY),
          titlesData: _titles(context, points,
              showLeftAxis: showLeftAxis,
              asEuro: asEuro,
              maxY: maxY,
              labelFormat: labelFormat),
          barTouchData:
              BarTouchData(touchTooltipData: _barTooltip(points, asEuro)),
          barGroups: [
            for (var i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: points[i].value,
                    width: width,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    color: gradientBars
                        ? null
                        : (colors != null
                            ? colors![i % colors!.length]
                            : AppColors.secondary),
                    gradient: gradientBars
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colors != null
                                  ? colors![i % colors!.length]
                                  : AppColors.secondary,
                              (colors != null
                                      ? colors![i % colors!.length]
                                      : AppColors.secondary)
                                  .withValues(alpha: 0.20),
                            ],
                          )
                        : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Line / area ────────────────────────────────────────────────────────────

/// Smooth gold line. With [filled] the area below fades from 0.3 gold to
/// transparent (the "area chart" of the spec); without it, a thin fill only.
class GoldLineChart extends StatelessWidget {
  final List<ChartPoint> points;
  final bool filled;
  final bool showLeftAxis;
  final bool asEuro;
  final Color color;

  /// Label of the point that gets an emphasised dot (e.g. the peak month).
  final String? highlight;

  const GoldLineChart({
    super.key,
    required this.points,
    this.filled = false,
    this.showLeftAxis = true,
    this.asEuro = false,
    this.color = _gold,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxY = points.fold<double>(1, (m, p) => p.value > m ? p.value : m);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: _axisMax(maxY),
          borderData: FlBorderData(show: false),
          gridData: _grid(context, maxY),
          titlesData: _titles(context, points,
              showLeftAxis: showLeftAxis, asEuro: asEuro, maxY: maxY),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => _gold,
              tooltipRoundedRadius: 8,
              getTooltipItems: (spots) => spots.map((s) {
                final i = s.x.toInt();
                final label =
                    i >= 0 && i < points.length ? points[i].label : '';
                return LineTooltipItem(
                  '$label\n${_fmtValue(s.y, asEuro)}',
                  const TextStyle(
                    color: Color(0xFF141313),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                );
              }).toList(),
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
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                // A dot per point on area charts; only the peak on line charts.
                checkToShowDot: (spot, _) {
                  if (highlight == null) return filled;
                  final i = spot.x.toInt();
                  return i >= 0 &&
                      i < points.length &&
                      points[i].label == highlight;
                },
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3.5,
                  color: color,
                  strokeWidth: 1.5,
                  strokeColor: AppColors.background,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: filled ? 0.30 : 0.12),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gold area chart — [GoldLineChart] with the gradient fill switched on.
class GoldAreaChart extends StatelessWidget {
  final List<ChartPoint> points;
  final bool showLeftAxis;

  const GoldAreaChart({
    super.key,
    required this.points,
    this.showLeftAxis = true,
  });

  @override
  Widget build(BuildContext context) => GoldLineChart(
        points: points,
        filled: true,
        showLeftAxis: showLeftAxis,
      );
}

// ─── Pie / donut ────────────────────────────────────────────────────────────

enum PieLegend { beside, below, none }

/// Donut chart with a punched-out centre and a dot legend.
class GoldPieChart extends StatefulWidget {
  final List<ChartPoint> points;
  final PieLegend legend;

  /// Painted into the donut hole so it reads as a hole, not a white disc.
  final Color? holeColor;
  final bool showPercentages;

  const GoldPieChart({
    super.key,
    required this.points,
    this.legend = PieLegend.beside,
    this.holeColor,
    this.showPercentages = true,
  });

  @override
  State<GoldPieChart> createState() => _GoldPieChartState();
}

class _GoldPieChartState extends State<GoldPieChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) return const SizedBox.shrink();
    final total = points.fold<double>(0, (s, p) => s + p.value);

    final chart = PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        centerSpaceColor: widget.holeColor ?? Colors.transparent,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions ||
                response?.touchedSection == null) {
              setState(() => _touched = -1);
              return;
            }
            setState(
                () => _touched = response!.touchedSection!.touchedSectionIndex);
          },
        ),
        sections: [
          for (var i = 0; i < points.length; i++)
            PieChartSectionData(
              // A zero slice would make the donut vanish; keep a hairline.
              value: points[i].value <= 0 ? 0.01 : points[i].value,
              color: kChartPalette[i % kChartPalette.length],
              radius: _touched == i ? 32 : 26,
              // A lone 100% slice puts its label on the thin ring band where
              // it overruns the edge — and the legend already says which
              // category it is, so the number adds nothing.
              showTitle:
                  widget.showPercentages && total > 0 && points.length > 1,
              title: total > 0
                  ? '${(points[i].value / total * 100).toStringAsFixed(0)}%'
                  : '',
              titleStyle: const TextStyle(
                color: Color(0xFF141313),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );

    if (widget.legend == PieLegend.none) return chart;

    final legend = _PieLegend(
      points: points,
      wrap: widget.legend == PieLegend.below,
    );

    return widget.legend == PieLegend.beside
        ? Row(
            children: [
              Expanded(flex: 3, child: chart),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: legend),
            ],
          )
        : Column(
            children: [
              Expanded(child: chart),
              const SizedBox(height: 14),
              legend,
            ],
          );
  }
}

class _PieLegend extends StatelessWidget {
  final List<ChartPoint> points;
  final bool wrap;

  const _PieLegend({required this.points, required this.wrap});

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (var i = 0; i < points.length && i < 6; i++)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kChartPalette[i % kChartPalette.length],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                points[i].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              ),
            ),
          ],
        ),
    ];

    if (wrap) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 8,
        children: entries,
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: e),
      ],
    );
  }
}
