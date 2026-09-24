import 'chart_data_point.dart';
import 'database/recording_session.dart';
import 'motion_detector.dart';

/// Kết quả phân tích & đánh giá cho một phiên ghi (thuật toán CV-based)
class SessionEvaluationResult {
  final RecordingSession session;
  final int totalSamples;

  /// Dự đoán của thuật toán: true = Có di chuyển, false = Không di chuyển
  final bool predictedIsMoving;

  /// Tỉ lệ cửa sổ có phiếu "di chuyển" (0..1)
  final double voteRatio;

  /// Tổng số cửa sổ trượt đã đánh giá
  final int totalWindows;

  /// Số cửa sổ có phiếu di chuyển
  final int movingVotes;

  /// Nhãn thực tế (Ground truth): true = Có di chuyển, false = Không di chuyển, null = Chưa xác định
  final bool? groundTruthIsMoving;

  /// Nguồn gốc gán nhãn thực tế ('auto_keyword', 'manual', 'unclassified')
  final String groundTruthSource;

  /// Config đã dùng
  final MotionConfig config;

  const SessionEvaluationResult({
    required this.session,
    required this.totalSamples,
    required this.predictedIsMoving,
    required this.voteRatio,
    required this.totalWindows,
    required this.movingVotes,
    required this.groundTruthIsMoving,
    this.groundTruthSource = 'auto_keyword',
    this.config = const MotionConfig(),
  });

  /// Thuật toán có đoán đúng hay không (null nếu không có Ground Truth)
  bool? get isCorrect {
    if (groundTruthIsMoving == null) return null;
    return predictedIsMoving == groundTruthIsMoving;
  }

  /// Thông báo giải thích chi tiết lý do dự đoán
  String get explanation {
    if (predictedIsMoving) {
      return 'Tỉ lệ cửa sổ di chuyển: ${(voteRatio * 100).toStringAsFixed(1)}% (≥ ${(config.sessionRatio * 100).toStringAsFixed(0)}%) → CÓ DI CHUYỂN';
    }
    return 'Tỉ lệ cửa sổ di chuyển: ${(voteRatio * 100).toStringAsFixed(1)}% (< ${(config.sessionRatio * 100).toStringAsFixed(0)}%) → KHÔNG DI CHUYỂN';
  }

  /// Tạo bản sao với Ground Truth được chỉnh sửa thủ công
  SessionEvaluationResult copyWithGroundTruth(bool? newGroundTruth) {
    return SessionEvaluationResult(
      session: session,
      totalSamples: totalSamples,
      predictedIsMoving: predictedIsMoving,
      voteRatio: voteRatio,
      totalWindows: totalWindows,
      movingVotes: movingVotes,
      groundTruthIsMoving: newGroundTruth,
      groundTruthSource: 'manual',
      config: config,
    );
  }
}

/// Tổng kết toàn bộ đợt đánh giá
class EvaluationReport {
  final List<SessionEvaluationResult> results;
  final int totalSessions;
  final int evaluatedCount;
  final int unclassifiedCount;
  final int correctCount;
  final int incorrectCount;
  final double accuracyPercentage;

  const EvaluationReport({
    required this.results,
    required this.totalSessions,
    required this.evaluatedCount,
    required this.unclassifiedCount,
    required this.correctCount,
    required this.incorrectCount,
    required this.accuracyPercentage,
  });

  /// Số phiên có nhãn thực tế là Di chuyển
  int get actualMovingCount =>
      results.where((r) => r.groundTruthIsMoving == true).length;

  /// Số phiên có nhãn thực tế là Không di chuyển
  int get actualStillCount =>
      results.where((r) => r.groundTruthIsMoving == false).length;

  /// True Positive (Thực tế: Di chuyển & Thuật toán: Di chuyển)
  int get truePositive => results
      .where((r) => r.groundTruthIsMoving == true && r.predictedIsMoving)
      .length;

  /// True Negative (Thực tế: Đứng yên & Thuật toán: Đứng yên)
  int get trueNegative => results
      .where((r) => r.groundTruthIsMoving == false && !r.predictedIsMoving)
      .length;

  /// False Positive (Thực tế: Đứng yên nhưng Thuật toán: Di chuyển)
  int get falsePositive => results
      .where((r) => r.groundTruthIsMoving == false && r.predictedIsMoving)
      .length;

  /// False Negative (Thực tế: Di chuyển nhưng Thuật toán: Đứng yên)
  int get falseNegative => results
      .where((r) => r.groundTruthIsMoving == true && !r.predictedIsMoving)
      .length;
}

/// Dịch vụ tính toán & đánh giá thuật toán phát hiện di chuyển (CV-based)
class AlgorithmEvaluationService {
  AlgorithmEvaluationService._();
  static final AlgorithmEvaluationService instance =
      AlgorithmEvaluationService._();

  /// Loại bỏ dấu tiếng Việt để so khớp từ khóa linh hoạt
  static String removeDiacritics(String str) {
    var result = str.toLowerCase();
    const withDiacritics =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const withoutDiacritics =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  /// Tự động xác định Ground Truth (Nhãn thực tế) từ chuỗi tag / label
  /// Trả về:
  /// - `true`: Có di chuyển
  /// - `false`: Không di chuyển
  /// - `null`: Không thể xác định được (chưa có nhãn hoặc không khớp từ khóa)
  bool? determineGroundTruth(String? label) {
    if (label == null) return null;
    final normalized = removeDiacritics(label.trim());
    if (normalized.isEmpty) return null;

    // 1. Kiểm tra nhóm KHÔNG DI CHUYỂN trước (để tránh "không di chuyển" bị nhận nhầm thành "di chuyển")
    const stillKeywords = [
      'khong di chuyen',
      'dung yen',
      'de ban',
      'dat ban',
      'de tren ban',
      'dat tren ban',
      'tinh',
      'ngoi yen',
      'ngoi',
      'still',
      'stop',
      'rest',
      'bat dong',
      'khong chuyen dong',
      'dung',
      'nam yen',
    ];

    for (final kw in stillKeywords) {
      if (normalized.contains(kw)) {
        return false;
      }
    }

    // 2. Kiểm tra nhóm CÓ DI CHUYỂN
    const movingKeywords = [
      'cam tren tay',
      'cam tay',
      'di cham',
      'di bo',
      'walk',
      'chay',
      'run',
      'jogging',
      'di chuyen',
      'moving',
      'motion',
      'bo tui',
      'tui quan',
      'xe may',
      'oto',
      'xe',
      'bike',
      'car',
      'di lai',
      'buoc chan',
      'hoat dong',
      'lac',
      'rung',
      'van dong',
    ];

    for (final kw in movingKeywords) {
      if (normalized.contains(kw)) {
        return true;
      }
    }

    return null;
  }

  /// Đánh giá một phiên ghi dựa trên các điểm dữ liệu `ChartDataPoint`
  /// sử dụng thuật toán CV-based (classifySession)
  SessionEvaluationResult evaluateSessionPoints({
    required RecordingSession session,
    required List<ChartDataPoint> points,
    bool? manualGroundTruth,
    MotionConfig config = const MotionConfig(),
  }) {
    final total = points.length;

    // Chuyển ChartDataPoint thành danh sách tSeconds & magnitude
    final List<double> tSeconds = [];
    final List<double> magnitudes = [];
    for (final p in points) {
      tSeconds.add(p.relativeTime);
      magnitudes.add(p.magnitude);
    }

    final result = MotionDetector.classifySession(
      tSeconds,
      magnitudes,
      config: config,
    );

    // Ước lượng số cửa sổ (để hiển thị chi tiết hơn)
    int movingVotes = 0;
    int totalWindows = 0;
    if (tSeconds.isNotEmpty) {
      final duration = tSeconds.last - tSeconds.first;
      final effectiveDuration = duration - config.skipSeconds;
      if (effectiveDuration > config.windowSeconds) {
        totalWindows =
            ((effectiveDuration - config.windowSeconds) / config.hopSeconds)
                .floor() +
            1;
        movingVotes = (result.ratio * totalWindows).round();
      }
    }

    final bool? groundTruth =
        manualGroundTruth ?? determineGroundTruth(session.label);
    final String source = manualGroundTruth != null
        ? 'manual'
        : (groundTruth != null ? 'auto_keyword' : 'unclassified');

    return SessionEvaluationResult(
      session: session,
      totalSamples: total,
      predictedIsMoving: result.isMoving,
      voteRatio: result.ratio,
      totalWindows: totalWindows,
      movingVotes: movingVotes,
      groundTruthIsMoving: groundTruth,
      groundTruthSource: source,
      config: config,
    );
  }

  /// Đánh giá một phiên ghi từ dữ liệu magnitude thô (relativeTime + magnitude)
  SessionEvaluationResult evaluateRawData({
    required RecordingSession session,
    required List<double> tSeconds,
    required List<double> magnitudes,
    bool? manualGroundTruth,
    MotionConfig config = const MotionConfig(),
  }) {
    final result = MotionDetector.classifySession(
      tSeconds,
      magnitudes,
      config: config,
    );

    final duration =
        tSeconds.isNotEmpty ? tSeconds.last - tSeconds.first : 0.0;
    final effectiveDuration = duration - config.skipSeconds;
    int totalWindows = 0;
    int movingVotes = 0;
    if (effectiveDuration > config.windowSeconds) {
      totalWindows =
          ((effectiveDuration - config.windowSeconds) / config.hopSeconds)
              .floor() +
          1;
      movingVotes = (result.ratio * totalWindows).round();
    }

    final bool? groundTruth =
        manualGroundTruth ?? determineGroundTruth(session.label);
    final String source = manualGroundTruth != null
        ? 'manual'
        : (groundTruth != null ? 'auto_keyword' : 'unclassified');

    return SessionEvaluationResult(
      session: session,
      totalSamples: tSeconds.length,
      predictedIsMoving: result.isMoving,
      voteRatio: result.ratio,
      totalWindows: totalWindows,
      movingVotes: movingVotes,
      groundTruthIsMoving: groundTruth,
      groundTruthSource: source,
      config: config,
    );
  }

  /// Tính toán báo cáo tổng hợp từ danh sách kết quả
  EvaluationReport generateReport(List<SessionEvaluationResult> results) {
    int evaluatedCount = 0;
    int unclassifiedCount = 0;
    int correctCount = 0;
    int incorrectCount = 0;

    for (final res in results) {
      if (res.groundTruthIsMoving == null) {
        unclassifiedCount++;
      } else {
        evaluatedCount++;
        if (res.isCorrect == true) {
          correctCount++;
        } else {
          incorrectCount++;
        }
      }
    }

    final double accuracyPct = evaluatedCount > 0
        ? (correctCount / evaluatedCount) * 100.0
        : 0.0;

    return EvaluationReport(
      results: results,
      totalSessions: results.length,
      evaluatedCount: evaluatedCount,
      unclassifiedCount: unclassifiedCount,
      correctCount: correctCount,
      incorrectCount: incorrectCount,
      accuracyPercentage: accuracyPct,
    );
  }
}
