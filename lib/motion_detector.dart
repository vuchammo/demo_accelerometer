import 'dart:math';

/// Các phân loại mẫu gia tốc
enum MotionSampleCategory {
  /// Gia tốc dưới ngưỡng tối thiểu (< thresholdMin)
  still,

  /// Gia tốc nằm trong dải chuyển động [thresholdMin, thresholdMax]
  motion,

  /// Gia tốc vượt ngưỡng tối đa (> thresholdMax, ví dụ xóc mạnh, va đập)
  spike,
}

/// Các cấp độ ghi log của MotionDetector
enum MotionLogLevel {
  /// In chi tiết từng mẫu 1 dòng gọn gàng + In banner nổi bật khi đổi trạng thái
  verbose,

  /// Chỉ in khi có sự kiện đổi trạng thái (STILL <-> MOVING) hoặc gặp Spike
  stateOnly,

  /// In tóm tắt cửa sổ mỗi 1-2 giây + In banner khi đổi trạng thái
  summary,

  /// Tắt hoàn toàn log console
  none,
}

/// Cấu trúc lưu trữ thông tin chi tiết của từng mẫu log
class MotionLogEntry {
  final DateTime timestamp;
  final double magnitude;
  final double? x;
  final double? y;
  final double? z;
  final MotionSampleCategory category;
  final int motionCount;
  final int stillCount;
  final int windowSize;
  final bool isMoving;
  final bool stateChanged;
  final String? triggerReason;
  final bool previousState;

  const MotionLogEntry({
    required this.timestamp,
    required this.magnitude,
    this.x,
    this.y,
    this.z,
    required this.category,
    required this.motionCount,
    required this.stillCount,
    required this.windowSize,
    required this.isMoving,
    required this.stateChanged,
    this.triggerReason,
    required this.previousState,
  });

  /// Định dạng giờ phút giây và mili-giây: HH:mm:ss.SSS
  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  /// Huy hiệu văn bản phân loại mẫu
  String get categoryBadge {
    switch (category) {
      case MotionSampleCategory.motion:
        return '[MOTION]';
      case MotionSampleCategory.still:
        return '[STILL ]';
      case MotionSampleCategory.spike:
        return '[SPIKE ]';
    }
  }

  /// Tên tiếng Việt của phân loại mẫu
  String get categoryName {
    switch (category) {
      case MotionSampleCategory.motion:
        return 'Chuyển động';
      case MotionSampleCategory.still:
        return 'Đứng yên';
      case MotionSampleCategory.spike:
        return 'Xóc mạnh';
    }
  }

  /// Thanh đo trực quan mini (10 ô) biểu diễn độ lớn gia tốc
  String get gaugeBar {
    const int totalBars = 10;
    const double maxDisplay = 10.0;
    final clamped = magnitude.clamp(0.0, maxDisplay);
    final filled = ((clamped / maxDisplay) * totalBars).round();
    final empty = totalBars - filled;
    return '[${'■' * filled}${'□' * empty}]';
  }

  /// Định dạng log 1 dòng trực quan cho Console
  String formatConsoleLine() {
    final magStr = magnitude.toStringAsFixed(2).padLeft(5);
    final stateStr = isMoving ? 'MOVING' : 'STILL';
    final progressStr = isMoving ? '$stillCount/30' : '$motionCount/28';

    return '[$formattedTime] $categoryBadge Mag: $magStr m/s² $gaugeBar | [$progressStr] | $stateStr';
  }

  /// Banner nổi bật in ra console khi có sự kiện đổi trạng thái
  String formatStateChangeBanner() {
    final fromState =
        previousState ? 'ĐANG CHUYỂN ĐỘNG' : 'ĐANG ĐỨNG YÊN';
    final toState =
        isMoving ? 'CÓ CHUYỂN ĐỘNG' : 'DỪNG CHUYỂN ĐỘNG';
    final reason = triggerReason ??
        (isMoving ? 'Đủ điểm chuyển động' : 'Đủ điểm đứng yên');
    final magStr = magnitude.toStringAsFixed(2);

    return '''
╔══════════════════════════════════════════════════════════════════════════╗
║ ⚡ [STATE CHANGED] $fromState  ➔  $toState
║ ⏱ Thời gian     : $formattedTime
║ 🎯 Lý do         : $reason
║ 📊 Mag kích hoạt : $magStr m/s²
╚══════════════════════════════════════════════════════════════════════════╝''';
  }
}

class MotionDetector {
  final double thresholdMin = 1.0;
  final double thresholdMax = 8.0;
  static const int windowSize = 30;
  static const int requiredMotionPoints = 28;
  static const int requiredStillPoints = 30;

  /// Kích thước tối đa của bộ nhớ đệm log
  static const int maxLogHistorySize = 50;

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

  /// Lịch sử log trong bộ nhớ phục vụ phân tích
  final List<MotionLogEntry> _logHistory = [];
  List<MotionLogEntry> get logHistory => List.unmodifiable(_logHistory);

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

    return _processSample(
      magnitude: magnitude,
      x: x,
      y: y,
      z: z,
      time: time,
    );
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
    );

    // Lưu vào bộ đệm xoay vòng
    _logHistory.insert(0, entry);
    if (_logHistory.length > maxLogHistorySize) {
      _logHistory.removeLast();
    }

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
      final shouldEmitSummary = _lastSummaryTime == null ||
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

  /// Xóa sạch lịch sử log
  void clearLogs() {
    _logHistory.clear();
  }

  /// Reset toàn bộ trạng thái cảm biến và log
  void reset() {
    _motionPointsCount = 0;
    _stillPointsCount = 0;
    _isMoving = false;
    _recentMagnitudes.clear();
    _magnitudeWindow.clear();
    _logHistory.clear();
    _samplesSinceLastSummary = 0;
    _lastSummaryTime = null;
  }
}
