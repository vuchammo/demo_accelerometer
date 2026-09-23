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
  final int requiredMotionPoints;
  final int requiredStillPoints;

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
    required this.requiredMotionPoints,
    required this.requiredStillPoints,
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
    final progressStr = isMoving
        ? '$stillCount/$requiredStillPoints'
        : '$motionCount/$requiredMotionPoints';

    return '[$formattedTime] $categoryBadge Mag: $magStr m/s² $gaugeBar | [$progressStr] | $stateStr';
  }

  /// Banner nổi bật in ra console khi có sự kiện đổi trạng thái
  String formatStateChangeBanner() {
    final fromState = previousState ? 'ĐANG CHUYỂN ĐỘNG' : 'ĐANG ĐỨNG YÊN';
    final toState = isMoving ? 'CÓ CHUYỂN ĐỘNG' : 'DỪNG CHUYỂN ĐỘNG';
    final reason =
        triggerReason ??
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
