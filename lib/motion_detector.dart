import 'dart:math';

import 'chart_data_point.dart';
import 'motion_log_models.dart';

class MotionDetector {
  final double thresholdMin = 1.0;
  final double thresholdMax = 8.0;
  static const int windowSize = 30;
  static const int requiredPoints = 30;

  MotionLogLevel logLevel = MotionLogLevel.verbose;

  void Function(MotionLogEntry entry)? onLog;

  void Function(String message)? logPrinter;

  final List<double> _recentMagnitudes = [];
  List<double> get recentMagnitudes => List.unmodifiable(_recentMagnitudes);

  final List<double> _magnitudeWindow = [];
  List<double> get magnitudeWindow => List.unmodifiable(_magnitudeWindow);

  final List<ChartDataPoint> _chartDataPoints = [];
  List<ChartDataPoint> get chartDataPoints =>
      List.unmodifiable(_chartDataPoints);

  // --- Recording ---
  DateTime? _startTime;
  DateTime? _recordingStartTime;
  bool _isRecording = false;
  bool get isRecording => _isRecording;
  final List<ChartDataPoint> _recordingBuffer = [];
  List<ChartDataPoint> get recordingBuffer =>
      List.unmodifiable(_recordingBuffer);

  bool _isMoving = false;
  bool get isMoving => _isMoving;

  int _motionPointsCount = 0;
  int get motionPointsCount => _motionPointsCount;
  int get consecutiveHighCount => _motionPointsCount;

  int _stillPointsCount = 0;
  int get stillPointsCount => _stillPointsCount;
  int get consecutiveLowCount => _stillPointsCount;

  int _samplesSinceLastSummary = 0;
  DateTime? _lastSummaryTime;

  static bool get isDebugMode {
    bool inDebug = false;
    assert(() {
      inDebug = true;
      return true;
    }());
    return inDebug;
  }

  bool addSample(double x, double y, double z, DateTime time) {
    final magnitude = sqrt(x * x + y * y + z * z);

    _recentMagnitudes.insert(0, magnitude);
    if (_recentMagnitudes.length > 10) {
      _recentMagnitudes.removeLast();
    }

    return _processSample(magnitude: magnitude, x: x, y: y, z: z, time: time);
  }

  bool addMagnitudeSample(double magnitude) {
    return _processSample(
      magnitude: magnitude,
      x: null,
      y: null,
      z: null,
      time: DateTime.now(),
    );
  }

  bool _processSample({
    required double magnitude,
    double? x,
    double? y,
    double? z,
    required DateTime time,
  }) {
    bool stateChanged = false;
    final bool previousState = _isMoving;
    String? triggerReason;

    _magnitudeWindow.add(magnitude);
    if (_magnitudeWindow.length > windowSize) {
      _magnitudeWindow.removeAt(0);
    }

    int motionCount = 0;
    int stillCount = 0;

    for (final magnitudeValue in _magnitudeWindow) {
      if (magnitudeValue >= thresholdMin && magnitudeValue <= thresholdMax) {
        motionCount++;
      } else if (magnitudeValue < thresholdMin) {
        stillCount++;
      }
    }

    _motionPointsCount = motionCount;
    _stillPointsCount = stillCount;

    if (!_isMoving) {
      if (motionCount >= requiredPoints) {
        _isMoving = true;
        stateChanged = true;
        triggerReason =
            'Đạt $motionCount/$windowSize điểm chuyển động (yêu cầu >= $requiredPoints)';
      }
    } else {
      if (_magnitudeWindow.length >= requiredPoints &&
          stillCount >= requiredPoints) {
        _isMoving = false;
        stateChanged = true;
        triggerReason =
            'Đạt $stillCount/$windowSize điểm đứng yên (yêu cầu >= $requiredPoints)';
      }
    }

    // Phân loại mẫu
    final MotionSampleCategory category;
    if (magnitude > thresholdMax) {
      category = MotionSampleCategory.spike;
    } else if (magnitude >= thresholdMin) {
      category = MotionSampleCategory.motion;
    } else {
      category = MotionSampleCategory.still;
    }

    final entry = MotionLogEntry(
      timestamp: time,
      magnitude: magnitude,
      x: x,
      y: y,
      z: z,
      category: category,
      motionCount: motionCount,
      stillCount: stillCount,
      windowSize: _magnitudeWindow.length,
      isMoving: _isMoving,
      stateChanged: stateChanged,
      triggerReason: triggerReason,
      previousState: previousState,
      requiredPoints: requiredPoints,
    );

    // Tính thời gian tương đối
    _startTime ??= time;
    final relativeTime = time.difference(_startTime!).inMilliseconds / 1000.0;

    final dataPoint = ChartDataPoint(
      magnitude: magnitude,
      timestamp: time,
      relativeTime: relativeTime,
      category: category,
      isMoving: _isMoving,
    );

    // Lưu data point cho biểu đồ real-time (giữ đủ thời gian ~8.0s để phóng to hoặc cuộn mượt)
    _chartDataPoints.add(dataPoint);
    while (_chartDataPoints.length > 150 ||
        (_chartDataPoints.isNotEmpty &&
            _chartDataPoints.first.relativeTime < relativeTime - 8.0)) {
      _chartDataPoints.removeAt(0);
    }

    // Lưu vào buffer nếu đang ghi (tính thời gian tương đối từ lúc bắt đầu ghi)
    if (_isRecording) {
      _recordingStartTime ??= time;
      final sessionRelativeTime =
          time.difference(_recordingStartTime!).inMilliseconds / 1000.0;
      _recordingBuffer.add(
        ChartDataPoint(
          magnitude: magnitude,
          timestamp: time,
          relativeTime: sessionRelativeTime,
          category: category,
          isMoving: _isMoving,
        ),
      );
    }

    _emitLog(entry);

    return stateChanged;
  }

  void _emitLog(MotionLogEntry entry) {
    onLog?.call(entry);

    if (!isDebugMode || logLevel == MotionLogLevel.none) return;

    final printer = logPrinter ?? print;

    if (entry.stateChanged) {
      printer(entry.formatStateChangeBanner());
      return;
    }

    if (logLevel == MotionLogLevel.stateOnly) {
      if (entry.category == MotionSampleCategory.spike) {
        printer(entry.formatConsoleLine());
      }
      return;
    }

    if (logLevel == MotionLogLevel.summary) {
      _samplesSinceLastSummary++;
      final now = entry.timestamp;
      final shouldEmitSummary =
          _lastSummaryTime == null ||
          now.difference(_lastSummaryTime!).inMilliseconds >= 1000 ||
          _samplesSinceLastSummary >= 15;

      if (shouldEmitSummary && _magnitudeWindow.isNotEmpty) {
        _lastSummaryTime = now;
        _samplesSinceLastSummary = 0;
        printer(_formatSummaryLine(entry));
      }
      return;
    }

    if (logLevel == MotionLogLevel.verbose) {
      printer(entry.formatConsoleLine());
    }
  }

  String _formatSummaryLine(MotionLogEntry entry) {
    if (_magnitudeWindow.isEmpty) return '';
    double min = _magnitudeWindow.first;
    double max = _magnitudeWindow.first;
    double sum = 0.0;
    for (final v in _magnitudeWindow) {
      if (v < min) min = v;
      if (v > max) max = v;
      sum += v;
    }
    final avg = sum / _magnitudeWindow.length;
    final timeStr = entry.formattedTime;
    final stateStr = entry.isMoving ? 'MOVING' : 'STILL';
    return '[$timeStr] [SUMMARY] Avg: ${avg.toStringAsFixed(2)} (Min: ${min.toStringAsFixed(2)}, Max: ${max.toStringAsFixed(2)}) | Window: [${entry.motionCount}/$requiredPoints | ${entry.stillCount}/$requiredPoints] | State: $stateStr';
  }

  /// Bắt đầu ghi lịch sử
  void startRecording() {
    _isRecording = true;
    _recordingStartTime = null;
    _recordingBuffer.clear();
  }

  /// Dừng ghi và trả về toàn bộ dữ liệu đã ghi
  List<ChartDataPoint> stopRecording() {
    _isRecording = false;
    _recordingStartTime = null;
    final result = List<ChartDataPoint>.from(_recordingBuffer);
    _recordingBuffer.clear();
    return result;
  }

  void reset() {
    _motionPointsCount = 0;
    _stillPointsCount = 0;
    _isMoving = false;
    _isRecording = false;
    _startTime = null;
    _recordingStartTime = null;
    _recentMagnitudes.clear();
    _magnitudeWindow.clear();
    _chartDataPoints.clear();
    _recordingBuffer.clear();
    _samplesSinceLastSummary = 0;
    _lastSummaryTime = null;
  }
}
