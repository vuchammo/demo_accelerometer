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

  /// Giá trị trung bình magnitude trong cửa sổ hiện tại
  final double mean;

  /// Hệ số biến thiên (Coefficient of Variation) = std / mean
  final double cv;

  /// Phiếu thô của cửa sổ hiện tại (true = vote di chuyển)
  final bool vote;

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
    required this.mean,
    required this.cv,
    required this.vote,
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
        return '${AnsiColor.yellow}[MOTION]${AnsiColor.reset}';
      case MotionSampleCategory.still:
        return '${AnsiColor.green}[STILL ]${AnsiColor.reset}';
      case MotionSampleCategory.spike:
        return '${AnsiColor.red}${AnsiColor.bold}[SPIKE ]${AnsiColor.reset}';
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

  /// Thanh đo trực quan mini (10 ô) biểu diễn độ lớn gia tốc kèm màu sắc ANSI
  String get gaugeBar {
    const int totalBars = 10;
    const double maxDisplay = 10.0;
    final clamped = magnitude.clamp(0.0, maxDisplay);
    final filled = ((clamped / maxDisplay) * totalBars).round();
    final empty = totalBars - filled;

    // Chọn màu dựa vào category mẫu gia tốc
    final String colorCode;
    switch (category) {
      case MotionSampleCategory.still:
        colorCode = AnsiColor.green;
        break;
      case MotionSampleCategory.motion:
        colorCode = AnsiColor.yellow;
        break;
      case MotionSampleCategory.spike:
        colorCode = AnsiColor.red;
        break;
    }

    final filledPart = filled > 0
        ? '$colorCode${'■' * filled}${AnsiColor.reset}'
        : '';
    final emptyPart = empty > 0
        ? '${AnsiColor.gray}${'□' * empty}${AnsiColor.reset}'
        : '';

    return '[$filledPart$emptyPart]';
  }

  /// Định dạng log 1 dòng trực quan cho Console
  String formatConsoleLine() {
    final magStr = magnitude.toStringAsFixed(2).padLeft(5);
    final stateStr = isMoving
        ? '${AnsiColor.yellow}MOVING${AnsiColor.reset}'
        : '${AnsiColor.cyan}STILL${AnsiColor.reset}';
    final cvStr = cv.toStringAsFixed(3);
    final meanStr = mean.toStringAsFixed(3);
    final voteStr = vote ? 'Y' : 'N';

    return '[$formattedTime] $categoryBadge Mag: $magStr m/s² $gaugeBar | CV=$cvStr Mean=$meanStr Vote=$voteStr | $stateStr';
  }

  /// Banner nổi bật in ra console khi có sự kiện đổi trạng thái
  String formatStateChangeBanner() {
    final fromState = previousState ? 'ĐANG CHUYỂN ĐỘNG' : 'ĐANG ĐỨNG YÊN';
    final toState = isMoving ? 'CÓ CHUYỂN ĐỘNG' : 'DỪNG CHUYỂN ĐỘNG';
    final stateColor = isMoving ? AnsiColor.yellow : AnsiColor.cyan;
    final reason =
        triggerReason ??
        (isMoving ? 'Đủ cửa sổ di chuyển liên tiếp' : 'Đủ cửa sổ đứng yên liên tiếp');
    final magStr = magnitude.toStringAsFixed(2);

    return '''
${AnsiColor.bold}$stateColor╔══════════════════════════════════════════════════════════════════════════╗
║ ⚡ [STATE CHANGED] $fromState  ➔  $toState
║ ⏱ Thời gian     : $formattedTime
║ 🎯 Lý do         : $reason
║ 📊 Mag kích hoạt : $magStr m/s²  |  CV: ${cv.toStringAsFixed(3)}  Mean: ${mean.toStringAsFixed(3)}
╚══════════════════════════════════════════════════════════════════════════╝${AnsiColor.reset}''';
  }
}

/// Bảng mã màu ANSI escape sequences dùng để tô màu console log
abstract class AnsiColor {
  static const String reset = '\x1B[0m';
  static const String bold = '\x1B[1m';
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String magenta = '\x1B[35m';
  static const String cyan = '\x1B[36m';
  static const String gray = '\x1B[90m';
}
