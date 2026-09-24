import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_data_point.dart';
import 'database/recording_database.dart';
import 'database/recording_session.dart';
import 'web_server/web_share_sheet.dart';

class RecordingDetailScreen extends StatefulWidget {
  final RecordingSession session;

  const RecordingDetailScreen({super.key, required this.session});

  @override
  State<RecordingDetailScreen> createState() => _RecordingDetailScreenState();
}

class _RecordingDetailScreenState extends State<RecordingDetailScreen> {
  late Future<List<ChartDataPoint>> _dataPointsFuture;
  late final TransformationController _transformationController;
  late RecordingSession _session;
  bool _hasModified = false;

  bool _showAvg = false;
  bool _showDots = true;
  bool _isInspectMode =
      false; // Khi bật: cuộn ngón tay sẽ di chuyển đường dóng để soi từng giá trị

  static const Color _bgColor = Color(0xFF1E2235);
  static const Color _gridColor = Colors.white12;
  static const Color _borderColor = Color(0xFF333B56);
  static const Color _lineColor = Color(0xFF00E5FF);
  static const Color _lineStartColor = Color(0xFF2979FF);
  static const double thresholdMin = 1.0;
  static const double thresholdMax = 8.0;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _transformationController = TransformationController();
    _loadData();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
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

  void _zoomIn() {
    _transformationController.value *= Matrix4.diagonal3Values(1.3, 1.0, 1.0);
  }

  void _zoomOut() {
    _transformationController.value *= Matrix4.diagonal3Values(0.77, 1.0, 1.0);
  }

  void _panLeft() {
    _transformationController.value *= Matrix4.translationValues(50, 0, 0);
  }

  void _panRight() {
    _transformationController.value *= Matrix4.translationValues(-50, 0, 0);
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  Future<void> _showEditTagDialog() async {
    final controller = TextEditingController(text: _session.label ?? '');
    final savedTags = await RecordingDatabase.instance.getSavedTags();
    if (!mounted) return;

    final newTag = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.label_outline, color: Colors.indigo.shade700),
                const SizedBox(width: 8.0),
                const Text('Gắn tag cho phiên'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Tên tag',
                    hintText: 'Nhập tên tag...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              controller.clear();
                              setDialogState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (savedTags.isNotEmpty) ...[
                  const SizedBox(height: 12.0),
                  Text(
                    'Tag đã dùng trước đó:',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: savedTags.map((s) {
                      final isSelected =
                          controller.text.trim().toLowerCase() ==
                          s.toLowerCase();
                      return ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '#$s',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        backgroundColor: isSelected
                            ? Colors.indigo.shade100
                            : Colors.grey.shade100,
                        onPressed: () {
                          controller.text = isSelected ? '' : s;
                          setDialogState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
            actions: [
              if (_session.label != null && _session.label!.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => Navigator.of(ctx).pop(''),
                  child: const Text('Xóa tag'),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                child: const Text('Lưu'),
              ),
            ],
          );
        },
      ),
    );

    if (newTag != null && mounted && _session.id != null) {
      final clean = newTag.isEmpty ? null : newTag;
      await RecordingDatabase.instance.updateSessionLabel(_session.id!, clean);
      setState(() {
        _session = _session.copyWith(label: clean);
        _hasModified = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              clean == null ? 'Đã xóa tag' : 'Đã gắn tag "#$clean"',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
        Navigator.of(context).pop(true);
      }
    }
  }

  Widget _buildTagBanner() {
    final hasTag = _session.label != null && _session.label!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: hasTag ? Colors.indigo.shade100 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            hasTag ? Icons.label : Icons.label_outline,
            size: 18.0,
            color: hasTag ? Colors.indigo.shade700 : Colors.grey.shade500,
          ),
          const SizedBox(width: 8.0),
          Text(
            'Tag: ',
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              hasTag ? '#${_session.label}' : 'Chưa có tag (chạm để thêm)',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: hasTag ? FontWeight.bold : FontWeight.normal,
                color: hasTag ? Colors.indigo.shade800 : Colors.grey.shade400,
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8.0),
            onTap: _showEditTagDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasTag ? Icons.edit_outlined : Icons.add,
                    size: 15.0,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    hasTag ? 'Đổi' : 'Thêm',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_hasModified);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FA),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_hasModified),
          ),
          title: Text(
            _session.formattedStartTime,
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.laptop_chromebook),
              tooltip: 'Xem trên máy tính (Wi-Fi)',
              onPressed: () => WebShareSheet.show(context),
            ),
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

            // Tìm max magnitude để hiển thị thống kê
            double maxMag = 0.0;
            for (final p in points) {
              if (p.magnitude > maxMag) maxMag = p.magnitude;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thẻ Tag / Nhãn
                  _buildTagBanner(),

                  // Thống kê 4 chỉ số chính của phiên
                  _buildStatsGrid(_session, points.length, maxMag),
                  const SizedBox(height: 16.0),

                  // Biểu đồ chi tiết toàn bộ phiên ghi với zoom & đường dóng
                  _buildChartSection(points, _session, maxMag),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsGrid(
    RecordingSession session,
    int actualSamples,
    double maxMag,
  ) {
    final totalSamples = actualSamples > 0
        ? actualSamples
        : session.totalSamples;

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
        const SizedBox(width: 8.0),
        Expanded(
          child: _statItem(
            'Số mẫu',
            totalSamples.toString(),
            Icons.data_usage,
            Colors.purple.shade700,
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: _statItem(
            'Max Mag',
            maxMag.toStringAsFixed(2),
            Icons.show_chart,
            Colors.red.shade700,
            unit: 'm/s²',
          ),
        ),
        const SizedBox(width: 8.0),
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
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 6.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4.0),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (unit != null)
            Text(
              unit,
              style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
            ),
          const SizedBox(height: 2.0),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(
    List<ChartDataPoint> points,
    RecordingSession session,
    double maxMag,
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

    // Thời gian chuẩn hóa bắt đầu từ 0
    final t0 = points.first.relativeTime;
    final lastT = points.last.relativeTime;
    final measuredDuration = max(0.5, lastT - t0);
    final durationSec = max(measuredDuration, session.durationMs / 1000.0);
    final chartMaxY = max(12.0, (maxMag + 2.0).ceilToDouble());

    return Container(
      padding: const EdgeInsets.fromLTRB(14.0, 14.0, 14.0, 14.0),
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
          // Toolbar điều khiển: Chế độ soi / kéo ở hàng trên, Layer (avg, dots) & Zoom/Pan ở hàng dưới
          Row(
            children: [
              const Text(
                'Biểu đồ chi tiết',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // Nút chuyển chế độ: Soi đường dóng vs Kéo cuộn
              InkWell(
                borderRadius: BorderRadius.circular(8.0),
                onTap: () {
                  setState(() {
                    _isInspectMode = !_isInspectMode;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
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
                        size: 14,
                        color: _isInspectMode ? _lineColor : Colors.white70,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        _isInspectMode ? 'Soi giá trị' : 'Kéo / Zoom',
                        style: TextStyle(
                          fontSize: 11.5,
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
          const SizedBox(height: 8.0),
          // Hàng nút điều khiển: Layer toggles (avg, dots) & Zoom / Pan
          Row(
            children: [
              // Nút bật/tắt đường trung bình
              SizedBox(
                height: 28,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                      fontSize: 12,
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
              _toolbarIconButton(
                icon: Icons.arrow_back_ios_new,
                tooltip: 'Dịch sang trái',
                onPressed: _panLeft,
              ),
              _toolbarIconButton(
                icon: Icons.arrow_forward_ios,
                tooltip: 'Dịch sang phải',
                onPressed: _panRight,
              ),
              const SizedBox(width: 6.0),
              _toolbarIconButton(
                icon: Icons.zoom_out,
                tooltip: 'Thu nhỏ',
                onPressed: _zoomOut,
              ),
              _toolbarIconButton(
                icon: Icons.zoom_in,
                tooltip: 'Phóng to',
                onPressed: _zoomIn,
              ),
              _toolbarIconButton(
                icon: Icons.refresh,
                tooltip: 'Đặt lại tỉ lệ (1x)',
                onPressed: _resetZoom,
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          // Khu vực hiển thị biểu đồ FlTransformationConfig
          SizedBox(
            height: 260,
            child: LineChart(
              transformationConfig: FlTransformationConfig(
                scaleAxis: FlScaleAxis.horizontal,
                minScale: 1.0,
                maxScale: 40.0,
                panEnabled: !_isInspectMode,
                scaleEnabled: true,
                transformationController: _transformationController,
              ),
              _buildLineChartData(points, t0, durationSec, chartMaxY),
              duration: Duration.zero,
            ),
          ),
          const SizedBox(height: 10.0),
          // Hướng dẫn tương tác
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isInspectMode ? Icons.touch_app : Icons.pinch,
                size: 13,
                color: Colors.white38,
              ),
              const SizedBox(width: 5.0),
              Text(
                _isInspectMode
                    ? 'Lướt ngón tay trên đồ thị để soi đường dóng và thông số'
                    : 'Dùng 2 ngón tay hoặc các nút trên để phóng to / thu nhỏ',
                style: const TextStyle(fontSize: 11.0, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData(
    List<ChartDataPoint> points,
    double t0,
    double durationSec,
    double chartMaxY,
  ) {
    if (_showAvg) {
      final avg = widget.session.avgMagnitude;
      final avgSpots = [FlSpot(0, avg), FlSpot(durationSec, avg)];
      return LineChartData(
        minX: 0,
        maxX: durationSec,
        minY: 0,
        maxY: chartMaxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
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
        titlesData: _buildTitlesData(durationSec),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: _borderColor),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: thresholdMin,
              color: Colors.amberAccent.withValues(alpha: 0.6),
              strokeWidth: 1.0,
              dashArray: [6, 4],
            ),
            HorizontalLine(
              y: thresholdMax,
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
            color: _lineColor,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: _lineColor.withValues(alpha: 0.1),
            ),
          ),
        ],
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final normX = p.relativeTime - t0;
      spots.add(FlSpot(normX, p.magnitude.clamp(0.0, chartMaxY)));
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
        drawHorizontalLine: true,
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
      titlesData: _buildTitlesData(durationSec),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: _borderColor),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: thresholdMin,
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
              labelResolver: (_) => 'Min ${thresholdMin.toStringAsFixed(1)}',
            ),
          ),
          HorizontalLine(
            y: thresholdMax,
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
              labelResolver: (_) => 'Max ${thresholdMax.toStringAsFixed(1)}',
            ),
          ),
        ],
      ),
      // Cấu hình đường dóng toàn chiều cao biểu đồ khi đưa ngón tay đến giá trị
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
                    strokeWidth: 1.5,
                    dashArray: [6, 3],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 5.5,
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
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(3)} m/s²\n',
                const TextStyle(
                  color: _lineColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
                children: [
                  TextSpan(
                    text: 'Thời điểm: +${spot.x.toStringAsFixed(2)}s',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.normal,
                      fontSize: 10.5,
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
          isCurved: true,
          curveSmoothness: 0.18,
          preventCurveOverShooting: true,
          barWidth: 2.8,
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
          gradient: const LinearGradient(colors: [_lineStartColor, _lineColor]),
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

  Widget _toolbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 4.0),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: IconButton(
        icon: Icon(icon, size: 15, color: Colors.white70),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
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
          reservedSize: 26,
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
                  fontSize: 9.5,
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
          reservedSize: 32,
          interval: 2,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            return Text(
              value.toInt().toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10.5,
                color: Colors.white54,
              ),
            );
          },
        ),
      ),
    );
  }
}
