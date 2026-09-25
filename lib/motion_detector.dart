import 'dart:math' as math;

import 'chart_data_point.dart';
import 'motion_log_models.dart';

// ---------------------------------------------------------------------------
// Thuật toán phát hiện di chuyển / đứng yên — v3 (tương thích đa thiết bị)
//
// Đầu vào: magnitude gia tốc tổng hợp, thời gian tính bằng GIÂY (double).
// Tần số lấy mẫu của máy có thể khác nhau (đã thử 10–12.5 Hz): dữ liệu được
// nội suy về lưới đều [MotionConfig.sampleRateHz].
//
// Khác với v2: v2 chỉ dựa vào việc dao động có DUY TRÌ hay không (CV thấp của
// đường bao). Khi người dùng chạm/vuốt/lướt màn hình trong lúc điện thoại vẫn
// nằm yên, dao động do ngón tay tạo ra cũng duy trì liên tục suốt phiên, nên
// v2 báo nhầm là MOVING.
//
// v3 thêm điều kiện: dao động phải CÓ TÍNH CHU KỲ (giống nhịp mang/cầm điện
// thoại khi di chuyển) chứ không chỉ liên tục. Đo bằng đỉnh tự tương quan
// (autocorrelation) của phần cao tần trong cửa sổ, ở độ trễ 0.24-1.44 giây
// (nhịp đi bộ / đung đưa tay). Chạm/vuốt tạo ra các cú giật không lặp lại
// theo nhịp nên đỉnh tự tương quan thường thấp hơn.
//
// Quyết định theo thời gian thực dùng bộ lọc đa số trượt trên N cửa sổ gần
// nhất, thay vì đếm "N cửa sổ liên tiếp" như v2 — mượt hơn, ít bị kẹt trạng
// thái khi có vài cửa sổ lẻ tẻ đổi chiều.
// ---------------------------------------------------------------------------

/// Cấu hình tham số cho thuật toán phát hiện di chuyển (v3).
class MotionConfig {
  const MotionConfig({
    this.sampleRateHz = 12.5,
    this.windowSamples = 50, // 4.0 s
    this.hopSamples = 6, // ~0.48 s
    this.envSamples = 10, // ~0.8 s, làm mượt cho CV
    this.hpSamples = 10, // ~0.8 s, làm mượt để tách phần cao tần (tự tương quan)
    this.lagLo = 3, // 0.24 s
    this.lagHi = 18, // 1.44 s
    this.cvMax = 0.30,
    this.meanMin = 0.30,
    this.peakMin = 0.20, // đỉnh tự tương quan tối thiểu để coi là "có chu kỳ"
    this.majorityWindow = 10, // số cửa sổ gần nhất xét bộ lọc đa số (~5 s)
    this.majorityFrac = 0.5, // tỉ lệ tối thiểu phải là "di chuyển"
    this.sessionRatio = 0.5,
    this.skipSeconds = 1.5,
  });

  /// Tần số lưới nội suy (Hz).
  final double sampleRateHz;

  /// Kích thước cửa sổ / bước trượt, tính bằng số mẫu trên lưới.
  final int windowSamples;
  final int hopSamples;

  /// Cửa sổ làm mượt đường bao (cho CV).
  final int envSamples;

  /// Cửa sổ trung bình trượt để tách phần cao tần (cho tự tương quan).
  final int hpSamples;

  /// Khoảng độ trễ (lag) để tìm đỉnh tự tương quan (nhịp đi bộ / đung đưa tay).
  final int lagLo;
  final int lagHi;

  /// Cửa sổ bỏ phiếu "di chuyển" nếu cv < cvMax, mean > meanMin, và peak > peakMin.
  /// meanMin cùng đơn vị với magnitude (đang ở thang ~m/s²; nếu máy trả về đơn vị
  /// khác, ví dụ g, hãy quy đổi trước hoặc đổi meanMin).
  final double cvMax;
  final double meanMin;

  /// Đỉnh tự tương quan tối thiểu để coi là "có chu kỳ".
  final double peakMin;

  /// Số cửa sổ gần nhất xét bộ lọc đa số.
  final int majorityWindow;

  /// Tỉ lệ tối thiểu phải là "di chuyển" trong bộ lọc đa số.
  final double majorityFrac;

  /// Chỉ dùng cho [MotionDetector.classifySession].
  final double sessionRatio;
  final double skipSeconds;

  double get windowSeconds => windowSamples / sampleRateHz;
  double get hopSeconds => hopSamples / sampleRateHz;
}

/// Kết quả của một cửa sổ trượt.
class MotionWindow {
  const MotionWindow({
    required this.endTime,
    required this.mean,
    required this.cv,
    required this.peak,
    required this.vote,
    required this.isMoving,
  });

  /// Thời điểm (giây) của mẫu cuối cửa sổ.
  final double endTime;

  /// Trung bình và CV của đường bao trong cửa sổ.
  final double mean;
  final double cv;

  /// Đỉnh tự tương quan (độ mạnh tính chu kỳ) trong khoảng [lagLo, lagHi).
  final double peak;

  /// Phiếu thô của riêng cửa sổ này (chưa qua bộ lọc đa số).
  final bool vote;

  /// Trạng thái sau bộ lọc đa số trượt: true = MOVING.
  final bool isMoving;

  @override
  String toString() =>
      'MotionWindow(t=${endTime.toStringAsFixed(2)}, mean=${mean.toStringAsFixed(2)}, '
      'cv=${cv.toStringAsFixed(2)}, peak=${peak.toStringAsFixed(2)}, '
      'vote=$vote, isMoving=$isMoving)';
}

/// Kết quả phân loại toàn bộ phiên ghi.
class SessionResult {
  const SessionResult({
    required this.isMoving,
    required this.ratio,
    this.totalWindows = 0,
    this.movingVotes = 0,
  });

  final bool isMoving;

  /// Tỉ lệ cửa sổ có phiếu "di chuyển" (0..1).
  final double ratio;

  /// Tổng số cửa sổ trượt đã phân tích
  final int totalWindows;

  /// Số cửa sổ có phiếu "di chuyển"
  final int movingVotes;
}

// ---------------------------------------------------------------------------
// Engine nội bộ: xử lý nội suy, cửa sổ trượt, đường bao năng lượng, CV,
// tự tương quan (autocorrelation), bộ lọc đa số trượt.
// ---------------------------------------------------------------------------
class _CvEngine {
  _CvEngine({required this.config});

  final MotionConfig config;

  final List<double> _buf = <double>[];
  double? _t0; // thời điểm mẫu đầu tiên (gốc của lưới nội suy)
  int _k = 0; // chỉ số điểm lưới kế tiếp cần sinh
  double _tp = 0; // mẫu thô trước đó
  double _mp = 0;
  int _dropped = 0; // số điểm lưới đã trượt khỏi đầu buffer

  /// Buffer tròn các phiếu gần nhất, dùng cho bộ lọc đa số.
  final List<int> _votes = <int>[];
  bool _moving = false;

  /// Trạng thái hiện tại (sau bộ lọc đa số).
  bool get isMoving => _moving;

  void reset() {
    _buf.clear();
    _t0 = null;
    _k = 0;
    _tp = 0;
    _mp = 0;
    _dropped = 0;
    _votes.clear();
    _moving = false;
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

  /// Trung bình trượt kiểu "same" (numpy convolve mode='same'): cùng độ dài
  /// với đầu vào, tâm hoá quanh mỗi mẫu. K có thể chẵn hoặc lẻ.
  static List<double> _movingAverageSame(List<double> w, int k) {
    final n = w.length;
    final start = (k - 1) ~/ 2;
    final out = List<double>.filled(n, 0.0);
    for (var i = 0; i < n; i++) {
      final fi = i + start; // chỉ số tương ứng trong convolution 'full'
      final lo = math.max(0, fi - k + 1);
      final hi = math.min(fi, n - 1);
      var total = 0.0;
      for (var m = lo; m <= hi; m++) {
        total += w[m];
      }
      out[i] = total / k;
    }
    return out;
  }

  void _drain(List<MotionWindow> out) {
    final n = config.windowSamples;
    while (_buf.length >= n) {
      final w = _buf.sublist(0, n);

      // --- CV của đường bao (làm mượt envSamples) ---
      final envK = config.envSamples;
      final ne = n - envK + 1;
      final env = List<double>.filled(ne, 0.0);
      for (var j = 0; j < ne; j++) {
        var a = 0.0;
        for (var i = 0; i < envK; i++) {
          a += w[j + i];
        }
        env[j] = a / envK;
      }
      var esum = 0.0;
      for (final e in env) {
        esum += e;
      }
      final mean = esum / ne;
      var esq = 0.0;
      for (final e in env) {
        final d = e - mean;
        esq += d * d;
      }
      final cv = math.sqrt(esq / ne) / (mean + 1e-9);

      // --- Phần cao tần (trừ trung bình trượt "same") cho tự tương quan ---
      final sm = _movingAverageSame(w, config.hpSamples);
      final hp = List<double>.filled(n, 0.0);
      for (var i = 0; i < n; i++) {
        hp[i] = w[i] - sm[i];
      }
      var denom = 0.0;
      for (final v in hp) {
        denom += v * v;
      }
      denom += 1e-9;
      var peak = 0.0;
      final lagHi = math.min(config.lagHi, n);
      for (var lag = config.lagLo; lag < lagHi; lag++) {
        var s = 0.0;
        for (var i = 0; i < n - lag; i++) {
          s += hp[i] * hp[i + lag];
        }
        final val = s / denom;
        if (val > peak) peak = val;
      }

      final vote = cv < config.cvMax && mean > config.meanMin && peak > config.peakMin;

      // --- Bộ lọc đa số trượt ---
      _votes.add(vote ? 1 : 0);
      if (_votes.length > config.majorityWindow) {
        _votes.removeAt(0);
      }
      final voteSum = _votes.fold<int>(0, (a, b) => a + b);
      _moving = (voteSum / _votes.length) >= config.majorityFrac;

      final endTime = _t0! + (_dropped + n - 1) / config.sampleRateHz;
      out.add(MotionWindow(
        endTime: endTime,
        mean: mean,
        cv: cv,
        peak: peak,
        vote: vote,
        isMoving: _moving,
      ));

      _buf.removeRange(0, config.hopSamples);
      _dropped += config.hopSamples;
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

  // --- Real-time Recording Prediction Stats ---
  int _recordingTotalWindows = 0;
  int _recordingMovingVotes = 0;

  /// Tổng số cửa sổ của phiên ghi hiện tại (sau skipSeconds)
  int get recordingTotalWindows => _recordingTotalWindows;

  /// Số cửa sổ bỏ phiếu "di chuyển" của phiên ghi hiện tại
  int get recordingMovingVotes => _recordingMovingVotes;

  /// Tỉ lệ cửa sổ di chuyển của phiên ghi hiện tại (0..1)
  double get recordingVoteRatio => _recordingTotalWindows > 0
      ? _recordingMovingVotes / _recordingTotalWindows
      : 0.0;

  /// Dự đoán tạm thời của phiên ghi hiện tại (true = CÓ DI CHUYỂN)
  bool get isCurrentRecordingPredictedMoving =>
      recordingVoteRatio >= config.sessionRatio;

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

  /// Đưa một mẫu thô (thời gian tính bằng giây, magnitude) trực tiếp vào engine.
  /// Trả về các cửa sổ mới hoàn thành (thường 0 hoặc 1).
  List<MotionWindow> add(double tSeconds, double magnitude) {
    return _engine.add(tSeconds, magnitude);
  }

  /// Đưa một mẫu cảm biến vào. Trả về true nếu trạng thái MOVING/STILL thay đổi.
  bool addSample(double x, double y, double z, DateTime time) {
    final magnitude = math.sqrt(x * x + y * y + z * z);

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
    double lastPeak = _lastWindow?.peak ?? 0;
    bool lastVote = _lastWindow?.vote ?? false;

    if (windows.isNotEmpty) {
      final latestWindow = windows.last;
      _lastWindow = latestWindow;
      lastMean = latestWindow.mean;
      lastCv = latestWindow.cv;
      lastPeak = latestWindow.peak;
      lastVote = latestWindow.vote;

      if (isDetectionEnabled) {
        final newMoving = latestWindow.isMoving;
        if (newMoving != _isMoving) {
          _isMoving = newMoving;
          stateChanged = true;
          triggerReason = newMoving
              ? 'CV=${lastCv.toStringAsFixed(3)} < ${config.cvMax}, Mean=${lastMean.toStringAsFixed(3)} > ${config.meanMin}, Peak=${lastPeak.toStringAsFixed(3)} > ${config.peakMin} (bộ lọc đa số)'
              : 'Không thỏa mãn điều kiện di chuyển (bộ lọc đa số)';
        }
      }

      // Cập nhật thống kê dự đoán cho phiên ghi hiện tại nếu đang ghi
      if (_isRecording) {
        _recordingStartTime ??= time;
        final sessionRelativeTime =
            time.difference(_recordingStartTime!).inMilliseconds / 1000.0;
        if (sessionRelativeTime >= config.skipSeconds) {
          for (final w in windows) {
            _recordingTotalWindows++;
            if (w.vote) _recordingMovingVotes++;
          }
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
      peak: lastPeak,
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
    return '[$timeStr] [SUMMARY] Mean: ${w.mean.toStringAsFixed(3)} | CV: ${w.cv.toStringAsFixed(3)} | Peak: ${w.peak.toStringAsFixed(3)} | Vote: ${w.vote} | State: $stateStr';
  }

  /// Bắt đầu ghi lịch sử
  void startRecording() {
    _isRecording = true;
    _recordingStartTime = null;
    _recordingTotalWindows = 0;
    _recordingMovingVotes = 0;
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
    _recordingTotalWindows = 0;
    _recordingMovingVotes = 0;
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
      return const SessionResult(
        isMoving: false,
        ratio: 0,
        totalWindows: 0,
        movingVotes: 0,
      );
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
    return SessionResult(
      isMoving: ratio >= config.sessionRatio,
      ratio: ratio,
      totalWindows: total,
      movingVotes: votes,
    );
  }
}
