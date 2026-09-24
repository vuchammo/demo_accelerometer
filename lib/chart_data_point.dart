import 'motion_log_models.dart';

/// Điểm dữ liệu cho biểu đồ real-time
class ChartDataPoint {
  /// Giá trị magnitude (m/s²)
  final double magnitude;

  /// Thời gian lấy mẫu
  final DateTime timestamp;

  /// Thời gian tương đối (giây) kể từ khi bắt đầu thu thập
  final double relativeTime;

  /// Phân loại mẫu: still / motion / spike
  final MotionSampleCategory category;

  /// Trạng thái detector tại thời điểm này
  final bool isMoving;

  const ChartDataPoint({
    required this.magnitude,
    required this.timestamp,
    required this.relativeTime,
    required this.category,
    required this.isMoving,
  });

  /// Tạo từ Map (đọc từ database)
  factory ChartDataPoint.fromMap(Map<String, dynamic> map) {
    return ChartDataPoint(
      magnitude: (map['magnitude'] as num).toDouble(),
      timestamp: DateTime.now(), // không lưu timestamp tuyệt đối trong DB
      relativeTime: (map['relative_time'] as num).toDouble(),
      category: MotionSampleCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => MotionSampleCategory.still,
      ),
      isMoving: (map['is_moving'] as int) == 1,
    );
  }

  /// Chuyển sang Map (lưu vào database)
  Map<String, dynamic> toMap(int sessionId) {
    return {
      'session_id': sessionId,
      'relative_time': relativeTime,
      'magnitude': magnitude,
      'category': category.name,
      'is_moving': isMoving ? 1 : 0,
    };
  }

  /// Chuyển sang JSON để truyền qua Web API
  Map<String, dynamic> toJson() {
    return {
      'relative_time': relativeTime,
      'magnitude': magnitude,
      'category': category.name,
      'is_moving': isMoving,
    };
  }
}
