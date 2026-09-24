import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_data_point.dart';
import 'motion_log_models.dart';

class MotionChart extends StatelessWidget {
  final List<ChartDataPoint> dataPoints;
  final double thresholdMin;
  final double thresholdMax;

  const MotionChart({
    super.key,
    required this.dataPoints,
    required this.thresholdMin,
    required this.thresholdMax,
  });

  static const double _maxY = 12.0;

  Color _colorForCategory(MotionSampleCategory category) {
    switch (category) {
      case MotionSampleCategory.still:
        return Colors.amber.shade600;
      case MotionSampleCategory.motion:
        return Colors.green.shade500;
      case MotionSampleCategory.spike:
        return Colors.red.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Biểu đồ Magnitude',
            style: TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16.0),
          SizedBox(
            height: 200.0,
            child: dataPoints.isEmpty
                ? const Center(
                    child: Text(
                      'Đang chờ dữ liệu...',
                      style: TextStyle(color: Colors.grey, fontSize: 14.0),
                    ),
                  )
                : _buildChart(),
          ),
          const SizedBox(height: 12.0),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i].magnitude.clamp(0, _maxY)));
    }

    // Tạo gradient stops dựa trên category từng điểm
    final gradientColors = <Color>[];
    final gradientStops = <double>[];
    if (dataPoints.length == 1) {
      gradientColors.add(_colorForCategory(dataPoints[0].category));
      gradientStops.add(0.0);
    } else {
      for (int i = 0; i < dataPoints.length; i++) {
        gradientColors.add(_colorForCategory(dataPoints[i].category));
        gradientStops.add(i / (dataPoints.length - 1));
      }
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (dataPoints.length - 1).toDouble().clamp(1, double.infinity),
        minY: 0,
        maxY: _maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2.0,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 2.0,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10.0,
                      color: Colors.grey.shade500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            // Đường ngưỡng tối thiểu
            HorizontalLine(
              y: thresholdMin,
              color: Colors.green.shade300,
              strokeWidth: 1.2,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 4, bottom: 2),
                style: TextStyle(
                  fontSize: 9.0,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w600,
                ),
                labelResolver: (_) => 'Min ${thresholdMin.toStringAsFixed(1)}',
              ),
            ),
            // Đường ngưỡng tối đa
            HorizontalLine(
              y: thresholdMax,
              color: Colors.red.shade300,
              strokeWidth: 1.2,
              dashArray: [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 4, bottom: 2),
                style: TextStyle(
                  fontSize: 9.0,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
                labelResolver: (_) => 'Max ${thresholdMax.toStringAsFixed(1)}',
              ),
            ),
          ],
        ),
        // Vùng tô nền giữa 2 ngưỡng (vùng chuyển động)
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            HorizontalRangeAnnotation(
              y1: thresholdMin,
              y2: thresholdMax,
              color: Colors.green.withValues(alpha: 0.06),
            ),
          ],
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey.shade800,
            tooltipRoundedRadius: 8.0,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= dataPoints.length) return null;
                final point = dataPoints[index];
                final categoryName = _categoryLabel(point.category);
                return LineTooltipItem(
                  '${point.magnitude.toStringAsFixed(2)} m/s²\n$categoryName',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            gradient: LinearGradient(
              colors: gradientColors,
              stops: gradientStops,
            ),
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                if (index < 0 || index >= dataPoints.length) {
                  return FlDotCirclePainter(radius: 2.0, color: Colors.grey);
                }
                final color = _colorForCategory(dataPoints[index].category);
                // Điểm cuối cùng lớn hơn
                final isLast = index == dataPoints.length - 1;
                return FlDotCirclePainter(
                  radius: isLast ? 4.0 : 2.0,
                  color: color,
                  strokeWidth: isLast ? 2.0 : 0,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: gradientColors
                    .map((c) => c.withValues(alpha: 0.12))
                    .toList(),
                stops: gradientStops,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
    );
  }

  String _categoryLabel(MotionSampleCategory category) {
    switch (category) {
      case MotionSampleCategory.still:
        return 'Đứng yên';
      case MotionSampleCategory.motion:
        return 'Chuyển động';
      case MotionSampleCategory.spike:
        return 'Xóc mạnh';
    }
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(Colors.amber.shade600, 'Đứng yên'),
        const SizedBox(width: 16.0),
        _legendItem(Colors.green.shade500, 'Chuyển động'),
        const SizedBox(width: 16.0),
        _legendItem(Colors.red.shade500, 'Xóc mạnh'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.0,
          height: 10.0,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4.0),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.0,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
