import 'motion_log_models.dart';

/// Điểm dữ liệu cho biểu đồ real-time
class ChartDataPoint {
  /// Giá trị magnitude (m/s²)
  final double magnitude;

  /// Thời gian lấy mẫu
  final DateTime timestamp;

  /// Phân loại mẫu: still / motion / spike
  final MotionSampleCategory category;

  /// Trạng thái detector tại thời điểm này
  final bool isMoving;

  const ChartDataPoint({
    required this.magnitude,
    required this.timestamp,
    required this.category,
    required this.isMoving,
  });
}
