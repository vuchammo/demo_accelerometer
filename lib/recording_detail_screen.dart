import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_data_point.dart';
import 'database/recording_database.dart';
import 'database/recording_session.dart';
import 'motion_log_models.dart';

class RecordingDetailScreen extends StatefulWidget {
  final RecordingSession session;

  const RecordingDetailScreen({super.key, required this.session});

  @override
  State<RecordingDetailScreen> createState() => _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends State<RecordingDetailScreen> {
  late Future<List<ChartDataPoint>> _dataPointsFuture;
  bool _showAvg = false;
  bool _expandedScroll = true;

  static const Color _bgColor = Color(0xFF282E45);
  static const Color _gridColor = Colors.white10;
  static const Color _borderColor = Color(0xff37434d);

  static const Color _stillColor = Color(0xFFFFC300);
  static const Color _motionColor = Color(0xFF3BFF49);
  static const Color _spikeColor = Color(0xFFE80054);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (widget.session.id != null) {
      _dataPointsFuture = RecordingDatabase.instance.getSessionDataPoints(
        widget.session.id!,
      );
    } else {
      _dataPointsFuture = Future.value([]);
    }
  }

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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa phiên ghi này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (widget.session.id != null) {
        await RecordingDatabase.instance.deleteSession(widget.session.id!);
      }
      if (mounted) {
        Navigator.of(context).pop(true); // true = was deleted
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(
          session.formattedStartTime,
          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Xóa phiên ghi',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: FutureBuilder<List<ChartDataPoint>>(
        future: _dataPointsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final points = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thống kê 3 chỉ số chính
                _buildStatsGrid(session, points.length),
                const SizedBox(height: 18.0),

                // Biểu đồ chi tiết toàn bộ phiên ghi
                _buildChartSection(points, session),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(RecordingSession session, int actualSamples) {
    final totalSamples = actualSamples > 0 ? actualSamples : session.totalSamples;

    return Row(
      children: [
        Expanded(
          child: _statItem(
            'Thời lượng',
            session.formattedDuration,
            Icons.timer_outlined,
            Colors.blue.shade700,
          ),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: _statItem(
            'Số mẫu',
            totalSamples.toString(),
            Icons.data_usage,
            Colors.purple.shade700,
          ),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: _statItem(
            'Avg Mag',
            session.avgMagnitude.toStringAsFixed(2),
            Icons.speed,
            Colors.teal.shade700,
            unit: 'm/s²',
          ),
        ),
      ],
    );
  }

  Widget _statItem(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? unit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10.0,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6.0),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (unit != null)
            Text(
              unit,
              style: TextStyle(fontSize: 10.0, color: Colors.grey.shade500),
            ),
          const SizedBox(height: 2.0),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.0, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(
    List<ChartDataPoint> points,
    RecordingSession session,
  ) {
    if (points.isEmpty) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: const Center(
          child: Text(
            'Không có dữ liệu điểm mẫu trong phiên này',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ),
      );
    }

    // Tính thời gian chuẩn hóa bắt đầu từ 0
    final t0 = points.first.relativeTime;
    final lastT = points.last.relativeTime;
    final measuredDuration = max(0.5, lastT - t0);
    final durationSec = max(measuredDuration, session.durationMs / 1000.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14.0, 16.0, 14.0, 14.0),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18.0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _expandedScroll ? Icons.unfold_less : Icons.unfold_more,
                      color: Colors.white70,
                      size: 20,
                    ),
                    tooltip: _expandedScroll ? 'Vừa màn hình' : 'Cuộn ngang',
                    onPressed: () {
                      setState(() {
                        _expandedScroll = !_expandedScroll;
                      });
                    },
                  ),
                  TextButton(
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
                ],
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final shouldScroll = _expandedScroll && durationSec > 4.0;
              final chartWidth = shouldScroll
                  ? max(availableWidth, durationSec * 32.0)
                  : availableWidth;

              final chartWidget = SizedBox(
                width: chartWidth,
                height: 240,
                child: LineChart(
                  _buildLineChartData(points, t0, durationSec),
                ),
              );

              if (shouldScroll) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: chartWidget,
                );
              }
              return chartWidget;
            },
          ),
          const SizedBox(height: 14.0),
          _buildLegend(),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData(
    List<ChartDataPoint> points,
    double t0,
    double durationSec,
  ) {
    // Tìm max magnitude để tự co dãn trục Y
    double maxMag = 0.0;
    for (final p in points) {
      if (p.magnitude > maxMag) maxMag = p.magnitude;
    }
    final chartMaxY = max(12.0, (maxMag + 2.0).ceilToDouble());

    if (_showAvg) {
      final avg = widget.session.avgMagnitude;
      final avgSpots = [
        FlSpot(0, avg),
        FlSpot(durationSec, avg),
      ];
      return LineChartData(
        minX: 0,
        maxX: durationSec,
        minY: 0,
        maxY: chartMaxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: _gridColor, strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              const FlLine(color: _gridColor, strokeWidth: 1),
        ),
        titlesData: _buildTitlesData(durationSec),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: _borderColor),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: avgSpots,
            isCurved: false,
            color: const Color(0xFF00D2FF),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF00D2FF).withValues(alpha: 0.12),
            ),
          ),
        ],
      );
    }

    final spots = <FlSpot>[];
    final visibleColors = <Color>[];
    final visibleStops = <double>[];

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final normX = p.relativeTime - t0;
      spots.add(FlSpot(normX, p.magnitude.clamp(0.0, chartMaxY)));
    }

    if (points.length <= 1) {
      visibleColors.add(
        _colorForCategory(points.isEmpty ? MotionSampleCategory.still : points[0].category),
      );
      visibleStops.add(0.0);
    } else {
      for (int i = 0; i < points.length; i++) {
        visibleColors.add(_colorForCategory(points[i].category));
        visibleStops.add(i / (points.length - 1));
      }
    }

    return LineChartData(
      minX: 0,
      maxX: durationSec,
      minY: 0,
      maxY: chartMaxY,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (value) =>
            const FlLine(color: _gridColor, strokeWidth: 1),
        getDrawingVerticalLine: (value) =>
            const FlLine(color: _gridColor, strokeWidth: 1),
      ),
      titlesData: _buildTitlesData(durationSec),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: _borderColor),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 1.0,
            color: _motionColor.withValues(alpha: 0.4),
            strokeWidth: 1.0,
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
              labelResolver: (_) => 'Min 1.0',
            ),
          ),
          HorizontalLine(
            y: 8.0,
            color: _spikeColor.withValues(alpha: 0.4),
            strokeWidth: 1.0,
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
              labelResolver: (_) => 'Max 8.0',
            ),
          ),
        ],
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.2,
          preventCurveOverShooting: true,
          barWidth: 3.0,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          gradient: LinearGradient(
            colors: visibleColors.length >= 2 ? visibleColors : [_stillColor, _motionColor],
            stops: visibleStops.length >= 2 ? visibleStops : [0.0, 1.0],
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: (visibleColors.length >= 2 ? visibleColors : [_stillColor, _motionColor])
                  .map((c) => c.withValues(alpha: 0.15))
                  .toList(),
              stops: visibleStops.length >= 2 ? visibleStops : [0.0, 1.0],
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF1B2339),
          tooltipRoundedRadius: 8.0,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              ChartDataPoint? closest;
              double minDist = double.infinity;
              for (final p in points) {
                final relX = p.relativeTime - t0;
                final dist = (relX - spot.x).abs();
                if (dist < minDist) {
                  minDist = dist;
                  closest = p;
                }
              }
              final label = closest != null ? '${_categoryLabel(closest.category)}\n' : '';
              return LineTooltipItem(
                '$label${spot.y.toStringAsFixed(2)} m/s² • ${spot.x.toStringAsFixed(1)}s',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  FlTitlesData _buildTitlesData(double durationSec) {
    final interval = max(1.0, (durationSec / 5).floorToDouble());

    return FlTitlesData(
      show: true,
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: interval,
          getTitlesWidget: (value, meta) {
            if (value < 0 || value > durationSec + 0.01) {
              return const SizedBox.shrink();
            }
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
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 34,
          interval: 2,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            return Text(
              value.toInt().toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.white54,
              ),
            );
          },
        ),
      ),
    );
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
