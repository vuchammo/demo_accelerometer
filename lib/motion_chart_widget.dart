import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_data_point.dart';

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
  static const double _windowDuration =
      3.0; // hiển thị 3 giây cuộn từ trái sang phải
  static const Color _bgColor = Color(0xFF1E2235);
  static const Color _gridColor = Colors.white12;
  static const Color _borderColor = Color(0xFF333B56);
  static const Color _lineColor = Color(
    0xFF00E5FF,
  ); // Electric Cyan theo phong cách Sample 11/12
  static const Color _lineStartColor = Color(0xFF2979FF); // Electric Blue

  late final TransformationController _transformationController;
  bool _showAvg = false;
  bool _showDots = true;
  bool _isInspectMode =
      false; // Khi bật: cuộn ngón tay sẽ di chuyển đường dóng để soi từng giá trị

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    _transformationController.value *= Matrix4.diagonal3Values(1.3, 1.0, 1.0);
  }

  void _zoomOut() {
    _transformationController.value *= Matrix4.diagonal3Values(0.77, 1.0, 1.0);
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final lastMag = widget.dataPoints.isNotEmpty
        ? widget.dataPoints.last.magnitude
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      padding: const EdgeInsets.fromLTRB(14.0, 16.0, 16.0, 12.0),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18.0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tiêu đề + Giá trị tức thời + Chế độ soi / kéo
          Row(
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Biểu đồ Real-time',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (lastMag != null) ...[
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: _lineColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: _lineColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '${lastMag.toStringAsFixed(2)} m/s²',
                          style: const TextStyle(
                            fontSize: 11.0,
                            fontWeight: FontWeight.bold,
                            color: _lineColor,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6.0),
              // Nút bật chế độ soi đường dóng vs zoom
              InkWell(
                borderRadius: BorderRadius.circular(8.0),
                onTap: () {
                  setState(() {
                    _isInspectMode = !_isInspectMode;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7.0,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: _isInspectMode
                        ? _lineColor.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: _isInspectMode ? _lineColor : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isInspectMode
                            ? Icons.touch_app
                            : Icons.pan_tool_outlined,
                        size: 13,
                        color: _isInspectMode ? _lineColor : Colors.white70,
                      ),
                      const SizedBox(width: 3.5),
                      Text(
                        _isInspectMode ? 'Soi giá trị' : 'Kéo/Zoom',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                          color: _isInspectMode ? _lineColor : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          // Hàng nút điều khiển: Layer toggles (avg, dots) & Zoom nhanh
          Row(
            children: [
              // Nút avg
              SizedBox(
                height: 28,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _showAvg = !_showAvg;
                    });
                  },
                  child: Text(
                    'avg',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _showAvg
                          ? _lineColor
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4.0),
              // Nút bật/tắt hiển thị điểm (dots)
              SizedBox(
                height: 28,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _showDots = !_showDots;
                    });
                  },
                  child: Text(
                    'dots',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: _showDots
                          ? _lineColor
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _zoomButton(
                icon: Icons.zoom_out,
                tooltip: 'Thu nhỏ',
                onPressed: _zoomOut,
              ),
              _zoomButton(
                icon: Icons.zoom_in,
                tooltip: 'Phóng to',
                onPressed: _zoomIn,
              ),
              _zoomButton(
                icon: Icons.refresh,
                tooltip: 'Đặt lại tỉ lệ (1x)',
                onPressed: _resetZoom,
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          // Chart tích hợp FlTransformationConfig
          AspectRatio(
            aspectRatio: 1.70,
            child: widget.dataPoints.isEmpty
                ? const Center(
                    child: Text(
                      'Đang chờ dữ liệu cảm biến...',
                      style: TextStyle(color: Colors.white38, fontSize: 13.0),
                    ),
                  )
                : LineChart(
                    transformationConfig: FlTransformationConfig(
                      scaleAxis: FlScaleAxis.horizontal,
                      minScale: 1.0,
                      maxScale: 30.0,
                      panEnabled: !_isInspectMode,
                      scaleEnabled: true,
                      transformationController: _transformationController,
                    ),
                    _showAvg ? _avgData() : _mainData(),
                    duration: Duration.zero,
                  ),
          ),
          const SizedBox(height: 8.0),
          // Gợi ý tương tác
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isInspectMode ? Icons.touch_app : Icons.pinch,
                size: 12,
                color: Colors.white38,
              ),
              const SizedBox(width: 4.0),
              Text(
                _isInspectMode
                    ? 'Lướt ngón tay để soi đường dóng và thông số'
                    : 'Dùng 2 ngón tay hoặc các nút trên để phóng to / thu nhỏ',
                style: const TextStyle(fontSize: 10.5, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _zoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 4.0),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: IconButton(
        icon: Icon(icon, size: 14, color: Colors.white70),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }

  // Tính window hiển thị (minX, maxX) dựa trên relativeTime để biểu đồ cuộn mượt
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
    for (int i = 0; i < widget.dataPoints.length; i++) {
      final p = widget.dataPoints[i];
      spots.add(FlSpot(p.relativeTime, p.magnitude.clamp(0, _maxY)));
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
        drawHorizontalLine: true,
        horizontalInterval: 2,
        verticalInterval: _windowDuration / 5,
        getDrawingHorizontalLine: (value) => const FlLine(
          color: _gridColor,
          strokeWidth: 0.8,
          dashArray: [8, 4],
        ),
        getDrawingVerticalLine: (value) => const FlLine(
          color: _gridColor,
          strokeWidth: 0.8,
          dashArray: [8, 4],
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: _windowDuration / 5,
            getTitlesWidget: _bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 2,
            getTitlesWidget: _leftTitleWidgets,
            reservedSize: 34,
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
            color: Colors.amberAccent.withValues(alpha: 0.75),
            strokeWidth: 1.2,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.amberAccent.withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
              ),
              labelResolver: (_) =>
                  'Min ${widget.thresholdMin.toStringAsFixed(1)}',
            ),
          ),
          HorizontalLine(
            y: widget.thresholdMax,
            color: Colors.redAccent.withValues(alpha: 0.75),
            strokeWidth: 1.2,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.redAccent.withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
              ),
              labelResolver: (_) =>
                  'Max ${widget.thresholdMax.toStringAsFixed(1)}',
            ),
          ),
        ],
      ),
      // Đường dóng khi người dùng chạm vào biểu đồ
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchSpotThreshold: 12,
        getTouchLineStart: (_, __) => -double.infinity,
        getTouchLineEnd: (_, __) => double.infinity,
        getTouchedSpotIndicator:
            (LineChartBarData barData, List<int> spotIndexes) {
              return spotIndexes.map((spotIndex) {
                return TouchedSpotIndicatorData(
                  const FlLine(
                    color: _lineColor,
                    strokeWidth: 1.2,
                    dashArray: [6, 3],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 5.0,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: _lineColor,
                      );
                    },
                  ),
                );
              }).toList();
            },
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF161926),
          tooltipRoundedRadius: 8.0,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(2)} m/s²\n',
                const TextStyle(
                  color: _lineColor,
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: '${spot.x.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10.5,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          gradient: const LinearGradient(colors: [_lineStartColor, _lineColor]),
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: _showDots,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 2.2,
                color: Colors.white,
                strokeWidth: 1.2,
                strokeColor: _lineColor,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                _lineColor.withValues(alpha: 0.22),
                _lineColor.withValues(alpha: 0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
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

    const blendedColor = Color(0xFF00E5FF);

    return LineChartData(
      minX: window.minX,
      maxX: window.maxX,
      minY: 0,
      maxY: _maxY,
      clipData: const FlClipData.all(),
      lineTouchData: LineTouchData(
        getTouchLineStart: (_, __) => -double.infinity,
        getTouchLineEnd: (_, __) => double.infinity,
        getTouchedSpotIndicator:
            (LineChartBarData barData, List<int> spotIndexes) {
              return spotIndexes.map((spotIndex) {
                return TouchedSpotIndicatorData(
                  const FlLine(
                    color: blendedColor,
                    strokeWidth: 1.2,
                    dashArray: [6, 3],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 5.0,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: blendedColor,
                      );
                    },
                  ),
                );
              }).toList();
            },
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF161926),
          tooltipRoundedRadius: 8.0,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                'Avg: ${avg.toStringAsFixed(2)} m/s²',
                const TextStyle(
                  color: blendedColor,
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
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
        getDrawingVerticalLine: (value) => const FlLine(
          color: _gridColor,
          strokeWidth: 0.8,
          dashArray: [8, 4],
        ),
        getDrawingHorizontalLine: (value) => const FlLine(
          color: _gridColor,
          strokeWidth: 0.8,
          dashArray: [8, 4],
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: _windowDuration / 5,
            getTitlesWidget: _bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: _leftTitleWidgets,
            reservedSize: 34,
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
            color: Colors.amberAccent.withValues(alpha: 0.6),
            strokeWidth: 1.0,
            dashArray: [6, 4],
          ),
          HorizontalLine(
            y: widget.thresholdMax,
            color: Colors.redAccent.withValues(alpha: 0.6),
            strokeWidth: 1.0,
            dashArray: [6, 4],
          ),
        ],
      ),
      lineBarsData: [
        LineChartBarData(
          spots: avgSpots,
          isCurved: false,
          color: blendedColor,
          barWidth: 3.5,
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
          fontSize: 9.5,
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
        fontSize: 11,
        color: Colors.white54,
      ),
      textAlign: TextAlign.left,
    );
  }
}
