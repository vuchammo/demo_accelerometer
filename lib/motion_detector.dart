import 'dart:math';

import 'motion_log_models.dart';

class MotionDetector {
  final double thresholdMin = 1.0;
  final double thresholdMax = 8.0;
  static const int windowSize = 30;
  static const int requiredMotionPoints = 28;
  static const int requiredStillPoints = 30;

  /// Cấp độ log hiện tại (mặc định verbose để theo dõi đầy đủ khi debug)
  MotionLogLevel logLevel = MotionLogLevel.verbose;

  /// Callback tùy chọn khi có mẫu log mới được tạo
  void Function(MotionLogEntry entry)? onLog;

  /// Tùy biến hàm in log (mặc định dùng print)
  void Function(String message)? logPrinter;

  final List<double> _recentMagnitudes = [];
  List<double> get recentMagnitudes => List.unmodifiable(_recentMagnitudes);

  final List<double> _magnitudeWindow = [];
  List<double> get magnitudeWindow => List.unmodifiable(_magnitudeWindow);

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

  /// Kiểm tra ứng dụng có đang chạy chế độ debug hay không (thuần Dart)
  static bool get isDebugMode {
    bool inDebug = false;
    assert(() {
      inDebug = true;
      return true;
    }());
    return inDebug;
  }

  /// Thêm mẫu cảm biến đầy đủ tọa độ x, y, z và thời gian
  bool addSample(double x, double y, double z, DateTime time) {
    final magnitude = sqrt(x * x + y * y + z * z);

    _recentMagnitudes.insert(0, magnitude);
    if (_recentMagnitudes.length > 10) {
      _recentMagnitudes.removeLast();
    }

    return _processSample(magnitude: magnitude, x: x, y: y, z: z, time: time);
  }

  /// Thêm mẫu độ lớn magnitude trực tiếp
  bool addMagnitudeSample(double magnitude) {
    return _processSample(
      magnitude: magnitude,
      x: null,
      y: null,
      z: null,
      time: DateTime.now(),
    );
  }

  /// Xử lý mẫu gia tốc và thuật toán cửa sổ trượt
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
      if (motionCount >= requiredMotionPoints) {
        _isMoving = true;
        stateChanged = true;
        triggerReason =
            'Đạt $motionCount/$windowSize điểm chuyển động (yêu cầu >= $requiredMotionPoints)';
      }
    } else {
      if (_magnitudeWindow.length >= requiredStillPoints &&
          stillCount >= requiredStillPoints) {
        _isMoving = false;
        stateChanged = true;
        triggerReason =
            'Đạt $stillCount/$requiredStillPoints điểm đứng yên liên tiếp';
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
      requiredMotionPoints: requiredMotionPoints,
      requiredStillPoints: requiredStillPoints,
    );

    // Phát log ra Console và Callback khi đang ở chế độ debug
    _emitLog(entry);

    return stateChanged;
  }

  /// Quản lý xuất log dựa trên cấp độ logLevel
  void _emitLog(MotionLogEntry entry) {
    onLog?.call(entry);

    // Chỉ in log ra console khi đang ở chế độ debug và logLevel != none
    if (!isDebugMode || logLevel == MotionLogLevel.none) return;

    final printer = logPrinter ?? print;

    // 1. Khi đổi trạng thái: luôn in banner nổi bật
    if (entry.stateChanged) {
      printer(entry.formatStateChangeBanner());
      return;
    }

    // 2. Cấp độ stateOnly: chỉ in thêm nếu gặp Spike bất thường
    if (logLevel == MotionLogLevel.stateOnly) {
      if (entry.category == MotionSampleCategory.spike) {
        printer(entry.formatConsoleLine());
      }
      return;
    }

    // 3. Cấp độ summary: định kỳ tóm tắt sau mỗi 1 giây hoặc 15 mẫu
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

    // 4. Cấp độ verbose: in từng mẫu gọn gàng
    if (logLevel == MotionLogLevel.verbose) {
      printer(entry.formatConsoleLine());
    }
  }

  /// Tạo dòng tóm tắt thông số cửa sổ trượt
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
    return '[$timeStr] [SUMMARY] Avg: ${avg.toStringAsFixed(2)} (Min: ${min.toStringAsFixed(2)}, Max: ${max.toStringAsFixed(2)}) | Window: [${entry.motionCount}/$requiredMotionPoints | ${entry.stillCount}/$requiredStillPoints] | State: $stateStr';
  }

  /// Reset toàn bộ trạng thái cảm biến và log
  void reset() {
    _motionPointsCount = 0;
    _stillPointsCount = 0;
    _isMoving = false;
    _recentMagnitudes.clear();
    _magnitudeWindow.clear();
    _samplesSinceLastSummary = 0;
    _lastSummaryTime = null;
  }
}
