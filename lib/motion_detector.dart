import 'dart:math';

import 'chart_data_point.dart';
import 'motion_log_models.dart';

// ---------------------------------------------------------------------------
// Thuật toán mới: phát hiện di chuyển bằng CV (hệ số biến thiên) trên cửa sổ
// trượt, kèm nội suy tuyến tính lên lưới đều và hysteresis.
//
// Ý tưởng: khi di chuyển, dao động DUY TRÌ liên tục và ổn định (std/mean nhỏ,
// không có quãng lặng). Khi đứng yên nhưng điện thoại bị cầm/chạm, tín hiệu là
// các cụm ngắn xen quãng lặng => hệ số biến thiên CV = std/mean lớn.
// Không dùng độ lớn tuyệt đối của magnitude.
//
// Thời gian luôn tính bằng GIÂY (double). Nếu sensor trả về micro/mili-giây
// thì đổi sang giây trước khi gọi [_CvEngine.add].
// ---------------------------------------------------------------------------

/// Cấu hình tham số cho thuật toán phát hiện di chuyển.
class MotionConfig {
  const MotionConfig({
    this.sampleRateHz = 12.5,
    this.windowSeconds = 2.5,
    this.hopSeconds = 0.5,
    this.cvMax = 0.50,
    this.meanMin = 0.60,
    this.enterCount = 3,
    this.exitCount = 4,
    this.sessionRatio = 0.5,
    this.skipSeconds = 1.5,
  });

  /// Tần số nội suy đều (Hz).
  final double sampleRateHz;

  /// Độ dài cửa sổ và bước trượt (giây).
  final double windowSeconds;
  final double hopSeconds;

  /// Cửa sổ được bỏ phiếu "di chuyển" nếu cv < cvMax và mean > meanMin.
  final double cvMax;
  final double meanMin;

  /// Số cửa sổ liên tiếp để vào MOVING / thoát về STILL (hysteresis).
  final int enterCount;
  final int exitCount;

  /// Chỉ dùng cho [classifySession].
  final double sessionRatio;
  final double skipSeconds;

  int get windowSamples => (windowSeconds * sampleRateHz).round();
  int get hopSamples => (hopSeconds * sampleRateHz).round();
}

/// Kết quả của một cửa sổ trượt.
class MotionWindow {
  const MotionWindow({
    required this.endTime,
    required this.mean,
    required this.cv,
    required this.vote,
    required this.isMoving,
  });

  /// Thời điểm (giây) của mẫu cuối cửa sổ.
  final double endTime;
  final double mean;
  final double cv;

  /// Phiếu thô của riêng cửa sổ này (chưa qua hysteresis).
  final bool vote;

  /// Trạng thái sau hysteresis: true = MOVING.
  final bool isMoving;

  @override
  String toString() =>
      'MotionWindow(t=${endTime.toStringAsFixed(2)}, mean=${mean.toStringAsFixed(2)}, '
      'cv=${cv.toStringAsFixed(2)}, vote=$vote, isMoving=$isMoving)';
}

/// Kết quả phân loại toàn bộ phiên ghi.
class SessionResult {
  const SessionResult({required this.isMoving, required this.ratio});

  final bool isMoving;

  /// Tỉ lệ cửa sổ có phiếu "di chuyển" (0..1).
  final double ratio;
}

// ---------------------------------------------------------------------------
// Engine nội bộ: xử lý nội suy, cửa sổ trượt, CV, hysteresis.
// ---------------------------------------------------------------------------
class _CvEngine {
  _CvEngine({required this.config})
      : _n = config.windowSamples,
        _hop = config.hopSamples;

  final MotionConfig config;
  final int _n;
  final int _hop;

  final List<double> _buf = <double>[];
  double? _t0;
  int _k = 0;
  double _tp = 0;
  double _mp = 0;
  int _dropped = 0;
  bool _moving = false;
  int _run = 0;

  bool get isMoving => _moving;

  void reset() {
    _buf.clear();
    _t0 = null;
    _k = 0;
    _tp = 0;
    _mp = 0;
    _dropped = 0;
    _moving = false;
    _run = 0;
  }

  /// Đưa một mẫu thô vào. Trả về các cửa sổ mới hoàn thành (thường 0 hoặc 1;
  /// có thể nhiều hơn nếu có khoảng trống thời gian dài giữa hai mẫu).
  /// Mẫu có thời gian không tăng sẽ bị bỏ qua.
  List<MotionWindow> add(double tSeconds, double magnitude) {
    final out = <MotionWindow>[];
    final t0 = _t0;
    if (t0 == null) {
      _t0 = tSeconds;
      _tp = tSeconds;
      _mp = magnitude;
      _k = 1;
      _buf.add(magnitude);
      _drain(out);
      return out;
    }
    if (tSeconds <= _tp) return out;

    // Nội suy tuyến tính các điểm lưới nằm trong (tp, t).
    while (true) {
      final g = t0 + _k / config.sampleRateHz;
      if (!(g < tSeconds)) break;
      _buf.add(_mp + (magnitude - _mp) * (g - _tp) / (tSeconds - _tp));
      _k++;
      _drain(out);
    }
    _tp = tSeconds;
    _mp = magnitude;
    return out;
  }

  void _drain(List<MotionWindow> out) {
    while (_buf.length >= _n) {
      var sum = 0.0;
      for (var i = 0; i < _n; i++) {
        sum += _buf[i];
      }
      final mean = sum / _n;
      var sq = 0.0;
      for (var i = 0; i < _n; i++) {
        final d = _buf[i] - mean;
        sq += d * d;
      }
      final std = sqrt(sq / _n);
      final cv = std / (mean + 1e-9);
      final vote = cv < config.cvMax && mean > config.meanMin;

      // Máy trạng thái có trễ (hysteresis).
      if (!_moving) {
        _run = vote ? _run + 1 : 0;
        if (_run >= config.enterCount) {
          _moving = true;
          _run = 0;
        }
      } else {
        _run = !vote ? _run + 1 : 0;
        if (_run >= config.exitCount) {
          _moving = false;
          _run = 0;
        }
      }

      final endTime = _t0! + (_dropped + _n - 1) / config.sampleRateHz;
      out.add(MotionWindow(
        endTime: endTime,
        mean: mean,
        cv: cv,
        vote: vote,
        isMoving: _moving,
      ));

      _buf.removeRange(0, _hop);
      _dropped += _hop;
    }
  }
}

// ---------------------------------------------------------------------------
// MotionDetector: bọc _CvEngine, giữ nguyên API cũ cho phần còn lại của app.
// ---------------------------------------------------------------------------
class MotionDetector {
  MotionDetector({this.config = const MotionConfig()})
      : _engine = _CvEngine(config: config);

  final MotionConfig config;

  /// Ngưỡng dùng cho phân loại trực quan (biểu đồ, danh sách mẫu).
  /// KHÔNG dùng trong logic phát hiện di chuyển.
  final double thresholdMin = 1.0;
  final double thresholdMax = 8.0;

  MotionLogLevel logLevel = MotionLogLevel.verbose;
  void Function(MotionLogEntry entry)? onLog;
  void Function(String message)? logPrinter;

  final _CvEngine _engine;

  final List<double> _recentMagnitudes = [];
  List<double> get recentMagnitudes => List.unmodifiable(_recentMagnitudes);

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

  /// Bật / Tắt thuật toán phán đoán trạng thái di chuyển / không di chuyển
  bool isDetectionEnabled = true;

  /// Thông tin cửa sổ mới nhất (để hiển thị trên UI)
  MotionWindow? _lastWindow;
  MotionWindow? get lastWindow => _lastWindow;

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

  /// Đưa một mẫu cảm biến vào. Trả về true nếu trạng thái MOVING/STILL thay đổi.
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

    // Chuyển DateTime thành giây tương đối (tránh mất precision ở epoch lớn)
    _startTime ??= time;
    final double tSeconds =
        time.difference(_startTime!).inMicroseconds / 1e6;
    final double relativeTime =
        time.difference(_startTime!).inMilliseconds / 1000.0;

    // Chạy engine CV
    final windows = _engine.add(tSeconds, magnitude);

    // Kiểm tra thay đổi trạng thái
    double lastMean = _lastWindow?.mean ?? 0;
    double lastCv = _lastWindow?.cv ?? 0;
    bool lastVote = _lastWindow?.vote ?? false;

    if (windows.isNotEmpty) {
      final latestWindow = windows.last;
      _lastWindow = latestWindow;
      lastMean = latestWindow.mean;
      lastCv = latestWindow.cv;
      lastVote = latestWindow.vote;

      if (isDetectionEnabled) {
        final newMoving = latestWindow.isMoving;
        if (newMoving != _isMoving) {
          _isMoving = newMoving;
          stateChanged = true;
          triggerReason = newMoving
              ? 'CV=${lastCv.toStringAsFixed(3)} < ${config.cvMax}, Mean=${lastMean.toStringAsFixed(3)} > ${config.meanMin} (${config.enterCount} cửa sổ liên tiếp)'
              : 'Không thỏa mãn điều kiện di chuyển (${config.exitCount} cửa sổ liên tiếp)';
        }
      }
    }

    // Phân loại mẫu (chỉ dùng cho biểu đồ / visual, không phải logic phát hiện)
    final MotionSampleCategory category;
    if (magnitude > thresholdMax) {
      category = MotionSampleCategory.spike;
    } else if (magnitude >= thresholdMin) {
      category = MotionSampleCategory.motion;
    } else {
      category = MotionSampleCategory.still;
    }

    final dataPoint = ChartDataPoint(
      magnitude: magnitude,
      timestamp: time,
      relativeTime: relativeTime,
      category: category,
      isMoving: _isMoving,
    );

    // Lưu data point cho biểu đồ real-time
    _chartDataPoints.add(dataPoint);
    while (_chartDataPoints.length > 150 ||
        (_chartDataPoints.isNotEmpty &&
            _chartDataPoints.first.relativeTime < relativeTime - 8.0)) {
      _chartDataPoints.removeAt(0);
    }

    // Lưu vào buffer nếu đang ghi
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

    // Log
    final entry = MotionLogEntry(
      timestamp: time,
      magnitude: magnitude,
      x: x,
      y: y,
      z: z,
      category: category,
      mean: lastMean,
      cv: lastCv,
      vote: lastVote,
      isMoving: _isMoving,
      stateChanged: stateChanged,
      triggerReason: triggerReason,
      previousState: previousState,
    );
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

      if (shouldEmitSummary && _lastWindow != null) {
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
    final w = _lastWindow;
    if (w == null) return '';
    final timeStr = entry.formattedTime;
    final stateStr = entry.isMoving ? 'MOVING' : 'STILL';
    return '[$timeStr] [SUMMARY] Mean: ${w.mean.toStringAsFixed(3)} | CV: ${w.cv.toStringAsFixed(3)} | Vote: ${w.vote} | State: $stateStr';
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
    _isMoving = false;
    _isRecording = false;
    _startTime = null;
    _recordingStartTime = null;
    _lastWindow = null;
    _recentMagnitudes.clear();
    _chartDataPoints.clear();
    _recordingBuffer.clear();
    _samplesSinceLastSummary = 0;
    _lastSummaryTime = null;
    _engine.reset();
  }

  /// Quyết định cho cả một đoạn ghi: bỏ [MotionConfig.skipSeconds] giây đầu
  /// (cảm biến khởi động / chưa cử động), rồi kết luận MOVING nếu
  /// tỉ lệ cửa sổ "di chuyển" >= [MotionConfig.sessionRatio].
  static SessionResult classifySession(
    List<double> tSeconds,
    List<double> magnitude, {
    MotionConfig config = const MotionConfig(),
  }) {
    if (tSeconds.isEmpty || tSeconds.length != magnitude.length) {
      return const SessionResult(isMoving: false, ratio: 0);
    }
    final start = tSeconds.first + config.skipSeconds;
    final engine = _CvEngine(config: config);
    var votes = 0;
    var total = 0;
    for (var i = 0; i < tSeconds.length; i++) {
      if (tSeconds[i] < start) continue;
      for (final w in engine.add(tSeconds[i], magnitude[i])) {
        total++;
        if (w.vote) votes++;
      }
    }
    final ratio = total == 0 ? 0.0 : votes / total;
    return SessionResult(isMoving: ratio >= config.sessionRatio, ratio: ratio);
  }
}
