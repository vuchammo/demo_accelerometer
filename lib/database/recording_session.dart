/// Model cho phiên ghi lịch sử
class RecordingSession {
  final int? id;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMs;
  final int totalSamples;
  final double avgMagnitude;
  final double motionPercentage;
  final String? label;

  const RecordingSession({
    this.id,
    required this.startTime,
    required this.endTime,
    required this.durationMs,
    required this.totalSamples,
    required this.avgMagnitude,
    required this.motionPercentage,
    this.label,
  });

  /// Thời lượng dạng Duration
  Duration get duration => Duration(milliseconds: durationMs);

  /// Format thời lượng: mm:ss
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format thời gian bắt đầu: dd/MM/yyyy HH:mm
  String get formattedStartTime {
    final d = startTime;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'duration_ms': durationMs,
      'total_samples': totalSamples,
      'avg_magnitude': avgMagnitude,
      'motion_percentage': motionPercentage,
      'label': label,
    };
  }

  factory RecordingSession.fromMap(Map<String, dynamic> map) {
    return RecordingSession(
      id: map['id'] as int?,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      durationMs: map['duration_ms'] as int,
      totalSamples: map['total_samples'] as int,
      avgMagnitude: (map['avg_magnitude'] as num).toDouble(),
      motionPercentage: (map['motion_percentage'] as num).toDouble(),
      label: map['label'] as String?,
    );
  }
}
