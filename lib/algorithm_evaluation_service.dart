import 'chart_data_point.dart';
import 'database/recording_session.dart';

/// Kết quả phân tích & đánh giá cho một phiên ghi
class SessionEvaluationResult {
  final RecordingSession session;
  final int totalSamples;
  final int moderateCount;
  final int highCount;
  final int peakCount;

  /// % Gia tốc mức vừa (1.0 <= mag < 4.0)
  final double moderatePercentage;

  /// % Gia tốc cao (4.0 <= mag <= 8.0)
  final double highPercentage;

  /// % Gia tốc cực đại (mag > 8.0)
  final double peakPercentage;

  /// % Gia tốc cao + cực đại (mag >= 4.0)
  final double highAndPeakPercentage;

  /// Dự đoán của thuật toán: true = Có di chuyển, false = Không di chuyển
  final bool predictedIsMoving;

  /// Nhãn thực tế (Ground truth): true = Có di chuyển, false = Không di chuyển, null = Chưa xác định
  final bool? groundTruthIsMoving;

  /// Nguồn gốc gán nhãn thực tế ('auto_keyword', 'manual', 'unclassified')
  final String groundTruthSource;

  const SessionEvaluationResult({
    required this.session,
    required this.totalSamples,
    required this.moderateCount,
    required this.highCount,
    required this.peakCount,
    required this.moderatePercentage,
    required this.highPercentage,
    required this.peakPercentage,
    required this.highAndPeakPercentage,
    required this.predictedIsMoving,
    required this.groundTruthIsMoving,
    this.groundTruthSource = 'auto_keyword',
  });

  /// Thuật toán có đoán đúng hay không (null nếu không có Ground Truth)
  bool? get isCorrect {
    if (groundTruthIsMoving == null) return null;
    return predictedIsMoving == groundTruthIsMoving;
  }

  /// Thông báo giải thích chi tiết lý do dự đoán
  String get explanation {
    if (predictedIsMoving) {
      return 'Thỏa mãn: Mức vừa ${moderatePercentage.toStringAsFixed(1)}% (> 30%) và Cao+Cực đại ${highAndPeakPercentage.toStringAsFixed(1)}% (< 5%)';
    }

    final List<String> reasons = [];
    if (moderatePercentage <= 30.0) {
      reasons.add(
        'Mức vừa chỉ đạt ${moderatePercentage.toStringAsFixed(1)}% (yêu cầu > 30%)',
      );
    }
    if (highAndPeakPercentage >= 5.0) {
      reasons.add(
        'Cao+Cực đại lên tới ${highAndPeakPercentage.toStringAsFixed(1)}% (yêu cầu < 5%)',
      );
    }

    if (reasons.isEmpty) {
      return 'Không thỏa mãn điều kiện di chuyển';
    }
    return reasons.join(' & ');
  }

  /// Tạo bản sao với Ground Truth được chỉnh sửa thủ công
  SessionEvaluationResult copyWithGroundTruth(bool? newGroundTruth) {
    return SessionEvaluationResult(
      session: session,
      totalSamples: totalSamples,
      moderateCount: moderateCount,
      highCount: highCount,
      peakCount: peakCount,
      moderatePercentage: moderatePercentage,
      highPercentage: highPercentage,
      peakPercentage: peakPercentage,
      highAndPeakPercentage: highAndPeakPercentage,
      predictedIsMoving: predictedIsMoving,
      groundTruthIsMoving: newGroundTruth,
      groundTruthSource: 'manual',
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
  int get actualMovingCount => results
      .where((r) => r.groundTruthIsMoving == true)
      .length;

  /// Số phiên có nhãn thực tế là Không di chuyển
  int get actualStillCount => results
      .where((r) => r.groundTruthIsMoving == false)
      .length;

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

/// Dịch vụ tính toán & đánh giá thuật toán phát hiện di chuyển
class AlgorithmEvaluationService {
  AlgorithmEvaluationService._();
  static final AlgorithmEvaluationService instance =
      AlgorithmEvaluationService._();

  /// Ngưỡng gia tốc mức vừa tối thiểu (> 30%)
  static const double moderateThresholdPct = 30.0;

  /// Ngưỡng gia tốc cao + cực đại tối đa (< 5%)
  static const double highAndPeakThresholdPct = 5.0;

  /// Ngưỡng gia tốc magnitude (m/s²)
  static const double minModerateMag = 1.0;
  static const double maxModerateMag = 4.0;
  static const double maxHighMag = 8.0;

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
  SessionEvaluationResult evaluateSessionPoints({
    required RecordingSession session,
    required List<ChartDataPoint> points,
    bool? manualGroundTruth,
  }) {
    int moderateCount = 0;
    int highCount = 0;
    int peakCount = 0;
    final total = points.length;

    for (final p in points) {
      final mag = p.magnitude;
      if (mag >= minModerateMag && mag < maxModerateMag) {
        moderateCount++;
      } else if (mag >= maxModerateMag && mag <= maxHighMag) {
        highCount++;
      } else if (mag > maxHighMag) {
        peakCount++;
      }
    }

    return _buildEvaluationResult(
      session: session,
      totalSamples: total,
      moderateCount: moderateCount,
      highCount: highCount,
      peakCount: peakCount,
      manualGroundTruth: manualGroundTruth,
    );
  }

  /// Đánh giá một phiên ghi dựa trên các số lượng mẫu đã đếm sẵn
  SessionEvaluationResult evaluateCountData({
    required RecordingSession session,
    required int totalSamples,
    required int moderateCount,
    required int highCount,
    required int peakCount,
    bool? manualGroundTruth,
  }) {
    return _buildEvaluationResult(
      session: session,
      totalSamples: totalSamples,
      moderateCount: moderateCount,
      highCount: highCount,
      peakCount: peakCount,
      manualGroundTruth: manualGroundTruth,
    );
  }

  /// Hàm xây dựng kết quả đánh giá theo thuật toán quy định
  SessionEvaluationResult _buildEvaluationResult({
    required RecordingSession session,
    required int totalSamples,
    required int moderateCount,
    required int highCount,
    required int peakCount,
    bool? manualGroundTruth,
  }) {
    final double moderatePct;
    final double highPct;
    final double peakPct;
    final double highAndPeakPct;

    if (totalSamples > 0) {
      moderatePct = (moderateCount / totalSamples) * 100.0;
      highPct = (highCount / totalSamples) * 100.0;
      peakPct = (peakCount / totalSamples) * 100.0;
      highAndPeakPct = ((highCount + peakCount) / totalSamples) * 100.0;
    } else {
      moderatePct = 0.0;
      highPct = 0.0;
      peakPct = 0.0;
      highAndPeakPct = 0.0;
    }

    // THUẬT TOÁN ĐỀ BÀI:
    // Gia tốc mức vừa > 30% VÀ Gia tốc cao + cực đại < 5% => CÓ DI CHUYỂN
    // Ngược lại => KHÔNG DI CHUYỂN
    final bool predictedIsMoving =
        (moderatePct > moderateThresholdPct) &&
        (highAndPeakPct < highAndPeakThresholdPct);

    final bool? groundTruth =
        manualGroundTruth ?? determineGroundTruth(session.label);
    final String source = manualGroundTruth != null
        ? 'manual'
        : (groundTruth != null ? 'auto_keyword' : 'unclassified');

    return SessionEvaluationResult(
      session: session,
      totalSamples: totalSamples,
      moderateCount: moderateCount,
      highCount: highCount,
      peakCount: peakCount,
      moderatePercentage: moderatePct,
      highPercentage: highPct,
      peakPercentage: peakPct,
      highAndPeakPercentage: highAndPeakPct,
      predictedIsMoving: predictedIsMoving,
      groundTruthIsMoving: groundTruth,
      groundTruthSource: source,
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
