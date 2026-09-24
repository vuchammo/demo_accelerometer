import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_data_point.dart';
import 'motion_log_models.dart';

class MotionChart extends StatefulWidget {
  final List<ChartDataPoint> dataPoints;
  final double thresholdMin;
  final double thresholdMax;

  const MotionChart({
    super.key,
    required this.dataPoints,
    required this.thresholdMin,
    required this.thresholdMax,
  });

  @override
  State<MotionChart> createState() => _MotionChartState();
}

class _MotionChartState extends State<MotionChart> {
  static const double _maxY = 12.0;
  static const double _windowDuration = 3.0; // hiển thị 3 giây
  static const Color _bgColor = Color(0xFF282E45);
  static const Color _gridColor = Colors.white10;
  static const Color _borderColor = Color(0xff37434d);

  bool _showAvg = false;

  // Màu cho từng category
  static const Color _stillColor = Color(0xFFFFC300); // Vàng
  static const Color _motionColor = Color(0xFF3BFF49); // Xanh lá
  static const Color _spikeColor = Color(0xFFE80054); // Đỏ

  Color _colorForCategory(MotionSampleCategory category) {
    switch (category) {
      case MotionSampleCategory.still:
        return _stillColor;
      case MotionSampleCategory.motion:
        return _motionColor;
      case MotionSampleCategory.spike:
        return _spikeColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      padding: const EdgeInsets.fromLTRB(12.0, 24.0, 18.0, 12.0),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20.0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: title + avg button
          Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 0, bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Biểu đồ Magnitude',
                  style: TextStyle(
                    fontSize: 15.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(
                  width: 60,
                  height: 34,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _showAvg = !_showAvg;
                      });
                    },
                    child: Text(
                      'avg',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _showAvg
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chart
          AspectRatio(
            aspectRatio: 1.70,
            child: widget.dataPoints.isEmpty
                ? const Center(
                    child: Text(
                      'Đang chờ dữ liệu...',
                      style: TextStyle(color: Colors.white38, fontSize: 14.0),
                    ),
                  )
                : LineChart(
                    _showAvg ? _avgData() : _mainData(),
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.linear,
                  ),
          ),
          const SizedBox(height: 16.0),
          _buildLegend(),
        ],
      ),
    );
  }

  // Tính window hiển thị (minX, maxX) dựa trên relativeTime
  ({double minX, double maxX}) _calcWindow() {
    if (widget.dataPoints.isEmpty) return (minX: 0, maxX: _windowDuration);
    final lastTime = widget.dataPoints.last.relativeTime;
    final maxX = lastTime < _windowDuration ? _windowDuration : lastTime;
    final minX = maxX - _windowDuration;
    return (minX: minX < 0 ? 0 : minX, maxX: maxX);
  }

  // --- Main Data ---
  LineChartData _mainData() {
    final window = _calcWindow();

    final spots = <FlSpot>[];
    final visibleColors = <Color>[];
    final visibleStops = <double>[];

    for (int i = 0; i < widget.dataPoints.length; i++) {
      final p = widget.dataPoints[i];
      spots.add(FlSpot(p.relativeTime, p.magnitude.clamp(0, _maxY)));
    }

    // Gradient colors cho visible data points
    if (widget.dataPoints.length == 1) {
      visibleColors.add(_colorForCategory(widget.dataPoints[0].category));
      visibleStops.add(0.0);
    } else {
      for (int i = 0; i < widget.dataPoints.length; i++) {
        visibleColors
            .add(_colorForCategory(widget.dataPoints[i].category));
        visibleStops.add(i / (widget.dataPoints.length - 1));
      }
    }

    return LineChartData(
      minX: window.minX,
      maxX: window.maxX,
      minY: 0,
      maxY: _maxY,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 2,
        verticalInterval: _windowDuration / 5,
        getDrawingHorizontalLine: (value) =>
            const FlLine(color: _gridColor, strokeWidth: 1),
        getDrawingVerticalLine: (value) =>
            const FlLine(color: _gridColor, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: _windowDuration / 5,
            getTitlesWidget: _bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 2,
            getTitlesWidget: _leftTitleWidgets,
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: _borderColor),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: widget.thresholdMin,
            color: _motionColor.withValues(alpha: 0.5),
            strokeWidth: 1.2,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              style: TextStyle(
                fontSize: 9.0,
                color: _motionColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
              labelResolver: (_) =>
                  'Min ${widget.thresholdMin.toStringAsFixed(1)}',
            ),
          ),
          HorizontalLine(
            y: widget.thresholdMax,
            color: _spikeColor.withValues(alpha: 0.5),
            strokeWidth: 1.2,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              style: TextStyle(
                fontSize: 9.0,
                color: _spikeColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
              labelResolver: (_) =>
                  'Max ${widget.thresholdMax.toStringAsFixed(1)}',
            ),
          ),
        ],
      ),
      rangeAnnotations: RangeAnnotations(
        horizontalRangeAnnotations: [
          HorizontalRangeAnnotation(
            y1: widget.thresholdMin,
            y2: widget.thresholdMax,
            color: _motionColor.withValues(alpha: 0.05),
          ),
        ],
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1B2339),
          tooltipRoundedRadius: 8.0,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              // Tìm data point gần nhất
              ChartDataPoint? closest;
              double minDist = double.infinity;
              for (final p in widget.dataPoints) {
                final dist = (p.relativeTime - spot.x).abs();
                if (dist < minDist) {
                  minDist = dist;
                  closest = p;
                }
              }
              if (closest == null) return null;
              final categoryName = _categoryLabel(closest.category);
              return LineTooltipItem(
                '${closest.magnitude.toStringAsFixed(2)} m/s²\n'
                '$categoryName • ${closest.relativeTime.toStringAsFixed(1)}s',
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
          curveSmoothness: 0.25,
          preventCurveOverShooting: true,
          gradient: LinearGradient(
            colors: visibleColors,
            stops: visibleStops,
          ),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: visibleColors
                  .map((c) => c.withValues(alpha: 0.3))
                  .toList(),
              stops: visibleStops,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ],
    );
  }

  // --- Average Data ---
  LineChartData _avgData() {
    if (widget.dataPoints.isEmpty) return _mainData();

    final window = _calcWindow();

    double sum = 0;
    for (final p in widget.dataPoints) {
      sum += p.magnitude;
    }
    final avg = sum / widget.dataPoints.length;

    final avgSpots = <FlSpot>[
      FlSpot(window.minX, avg.clamp(0, _maxY)),
      FlSpot(window.maxX, avg.clamp(0, _maxY)),
    ];

    const blendedColor = Color(0xFF50E4FF);

    return LineChartData(
      minX: window.minX,
      maxX: window.maxX,
      minY: 0,
      maxY: _maxY,
      clipData: const FlClipData.all(),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1B2339),
          tooltipRoundedRadius: 8.0,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                'Avg: ${avg.toStringAsFixed(2)} m/s²',
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
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: true,
        horizontalInterval: 2,
        verticalInterval: _windowDuration / 5,
        getDrawingVerticalLine: (value) =>
            const FlLine(color: _borderColor, strokeWidth: 1),
        getDrawingHorizontalLine: (value) =>
            const FlLine(color: _borderColor, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: _windowDuration / 5,
            getTitlesWidget: _bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: _leftTitleWidgets,
            reservedSize: 42,
            interval: 2,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: _borderColor),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: widget.thresholdMin,
            color: _motionColor.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [6, 4],
          ),
          HorizontalLine(
            y: widget.thresholdMax,
            color: _spikeColor.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [6, 4],
          ),
        ],
      ),
      lineBarsData: [
        LineChartBarData(
          spots: avgSpots,
          isCurved: false,
          color: blendedColor,
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: blendedColor.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  // --- Title widgets ---
  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    return SideTitleWidget(
      meta: meta,
      child: Text(
        '${value.toStringAsFixed(1)}s',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 10,
          color: Colors.white38,
        ),
      ),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    if (value == meta.max || value == meta.min) return const SizedBox.shrink();
    return Text(
      value.toInt().toString(),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: Colors.white54,
      ),
      textAlign: TextAlign.left,
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
        _legendItem(_stillColor, 'Đứng yên'),
        const SizedBox(width: 16.0),
        _legendItem(_motionColor, 'Chuyển động'),
        const SizedBox(width: 16.0),
        _legendItem(_spikeColor, 'Xóc mạnh'),
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
          style: const TextStyle(
            fontSize: 11.0,
            color: Colors.white54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
