import 'dart:async';

import 'package:demo_accelerometer/motion_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'database/recording_database.dart';
import 'database/recording_session.dart';
import 'foreground_service_manager.dart';
import 'motion_chart_widget.dart';
import 'motion_log_models.dart';
import 'notification_service.dart';
import 'recording_history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const MotionDetectorView(),
    ),
  );
}

class MotionDetectorView extends StatefulWidget {
  const MotionDetectorView({super.key});

  @override
  State<MotionDetectorView> createState() => _MotionDetectorViewState();
}

class _MotionDetectorViewState extends State<MotionDetectorView> {
  final MotionDetector _detector = MotionDetector();

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  static const Duration _sampleInterval = Duration(milliseconds: 100);

  DateTime _stateChangedTime = DateTime.now();
  Timer? _clockTimer;
  bool _showChart = false;
  bool _showMagnitudeList = true;

  // Cài đặt hẹn giờ
  int _startDelaySeconds = 10; // 0 = ngay lập tức; 5, 10, 15, 30...
  int _autoStopSeconds = 0; // 0 = thủ công; 30, 60, 120, 300...

  // Trạng thái đếm ngược trước khi bắt đầu
  bool _isCountingDown = false;
  int _countdownRemaining = 0;
  Timer? _countdownTimer;

  // Trạng thái ghi phiên
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Duration _recordingElapsed = Duration.zero;
  Timer? _recordingTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    ForegroundServiceManager.instance.startService();
    _startListening();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _startListening() {
    _subscription =
        userAccelerometerEventStream(samplingPeriod: _sampleInterval)
            .throttleTime(const Duration(milliseconds: 70))
            .listen(
              (UserAccelerometerEvent event) {
                final now = DateTime.now();

                final stateChanged = _detector.addSample(
                  event.x,
                  event.y,
                  event.z,
                  event.timestamp,
                );

                if (stateChanged) {
                  _stateChangedTime = now;
                  NotificationService.instance.showMovementNotification(
                    isMoving: _detector.isMoving,
                  );
                }
                if (mounted) {
                  setState(() {});
                }
              },
              onError: (e) {},
              cancelOnError: true,
            );
  }

  void _onPressStartRecording() {
    if (_startDelaySeconds > 0) {
      setState(() {
        _isCountingDown = true;
        _countdownRemaining = _startDelaySeconds;
      });
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _countdownRemaining--;
        });
        if (_countdownRemaining <= 0) {
          timer.cancel();
          setState(() {
            _isCountingDown = false;
          });
          _startRecording();
        }
      });
    } else {
      _startRecording();
    }
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _countdownRemaining = 0;
    });
  }

  void _skipCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _countdownRemaining = 0;
    });
    _startRecording();
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _recordingElapsed = Duration.zero;
    });
    _detector.startRecording();
    NotificationService.instance.showRecordingStartedNotification();

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isRecording && _recordingStartTime != null) {
        final elapsed = DateTime.now().difference(_recordingStartTime!);
        setState(() {
          _recordingElapsed = elapsed;
        });

        // Tự động dừng khi chạm mốc thời gian cài đặt
        if (_autoStopSeconds > 0 && elapsed.inSeconds >= _autoStopSeconds) {
          _stopRecording();
        }
      }
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _isSaving) return;
    _recordingTimer?.cancel();
    final endTime = DateTime.now();
    final startTime = _recordingStartTime ?? endTime;
    final duration = endTime.difference(startTime);
    final durationMs = duration.inMilliseconds;
    final points = _detector.stopRecording();

    setState(() {
      _isRecording = false;
      _isSaving = true;
    });

    if (points.isEmpty) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có dữ liệu để lưu')),
        );
      }
      return;
    }

    final totalSamples = points.length;
    final sumMag = points.fold<double>(0.0, (sum, p) => sum + p.magnitude);
    final avgMag = sumMag / totalSamples;
    final motionCount = points
        .where((p) => p.category == MotionSampleCategory.motion)
        .length;
    final motionPercentage = (motionCount / totalSamples) * 100.0;

    final session = RecordingSession(
      startTime: startTime,
      endTime: endTime,
      durationMs: durationMs,
      totalSamples: totalSamples,
      avgMagnitude: avgMag,
      motionPercentage: motionPercentage,
    );

    try {
      final sessionId = await RecordingDatabase.instance.insertSession(session);
      await RecordingDatabase.instance.insertDataPoints(sessionId, points);

      // Phát thông báo khi đã dừng và lưu phiên
      await NotificationService.instance.showRecordingStoppedNotification(
        totalSamples: totalSamples,
        duration: duration,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã lưu phiên: $totalSamples mẫu (${(durationMs / 1000).toStringAsFixed(1)}s)',
            ),
            action: SnackBarAction(
              label: 'Xem lịch sử',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RecordingHistoryScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi lưu dữ liệu: $e')));
      }
    }
  }

  String _formatDelayLabel(int seconds) {
    if (seconds == 0) return 'Ngay';
    return '${seconds}s';
  }

  String _formatAutoStopLabel(int seconds) {
    if (seconds == 0) return 'Tự do';
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '$m phút' : '$m phút $s giây';
  }

  String _formatRecordingTimer(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    _subscription?.cancel();
    ForegroundServiceManager.instance.stopService();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    return (duration.inMilliseconds / 1000).toDouble().toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final isMoving = _detector.isMoving;
    final currentDuration = DateTime.now().difference(_stateChangedTime);

    final backgroundColor = isMoving
        ? Colors.green.shade600
        : Colors.red.shade600;

    final shadowColor = (isMoving ? Colors.green : Colors.red).withValues(
      alpha: 0.35,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text(
          'Phát Hiện Chuyển Động',
          style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Lịch sử ghi',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecordingHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: WithForegroundTask(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: 140.0,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 20.0),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(24.0),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 20.0,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isMoving ? 'Có chuyển động' : 'Không chuyển động',
                            style: const TextStyle(
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            _formatDuration(currentDuration),
                            style: const TextStyle(
                              fontSize: 52.0,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.0,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14.0),
                    // Khu vực điều khiển ghi dữ liệu
                    _buildRecordingControlCard(),
                    const SizedBox(height: 14.0),
                    // Toggle biểu đồ
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.show_chart_rounded,
                            color: _showChart
                                ? Colors.blue.shade600
                                : Colors.grey.shade400,
                            size: 22.0,
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                              'Biểu đồ real-time',
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w600,
                                color: _showChart
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          Switch(
                            value: _showChart,
                            activeThumbColor: Colors.blue.shade600,
                            onChanged: (value) {
                              setState(() {
                                _showChart = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // Biểu đồ (ẩn/hiện)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _showChart
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14.0),
                              child: MotionChart(
                                dataPoints: _detector.chartDataPoints,
                                thresholdMin: _detector.thresholdMin,
                                thresholdMax: _detector.thresholdMax,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 14.0),
                    // Toggle danh sách magnitude
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.list_alt_rounded,
                            color: _showMagnitudeList
                                ? Colors.blue.shade600
                                : Colors.grey.shade400,
                            size: 22.0,
                          ),
                          const SizedBox(width: 10.0),
                          Expanded(
                            child: Text(
                              '10 mẫu gần nhất',
                              style: TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w600,
                                color: _showMagnitudeList
                                    ? Colors.black87
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                          Switch(
                            value: _showMagnitudeList,
                            activeThumbColor: Colors.blue.shade600,
                            onChanged: (value) {
                              setState(() {
                                _showMagnitudeList = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // Danh sách magnitude (ẩn/hiện)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _showMagnitudeList
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14.0),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                ),
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 16.0,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '10 mẫu gần nhất',
                                          style: TextStyle(
                                            fontSize: 15.0,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                            vertical: 4.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8.0,
                                            ),
                                          ),
                                          child: Text(
                                            'Ngưỡng: ${_detector.thresholdMin} - ${_detector.thresholdMax}',
                                            style: TextStyle(
                                              fontSize: 12.0,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12.0),
                                    Column(
                                      children: List.generate(10, (index) {
                                        final hasData =
                                            index <
                                            _detector.recentMagnitudes.length;
                                        final mag = hasData
                                            ? _detector.recentMagnitudes[index]
                                            : null;
                                        final isNewest = index == 0 && hasData;
                                        final inMotion =
                                            hasData &&
                                            mag! >= _detector.thresholdMin &&
                                            mag <= _detector.thresholdMax;

                                        return Container(
                                          height: 32.0,
                                          margin: const EdgeInsets.only(
                                            bottom: 5.0,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12.0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: !hasData
                                                ? Colors.grey.shade50
                                                : (inMotion
                                                      ? Colors.green.shade50
                                                      : Colors.grey.shade50),
                                            borderRadius: BorderRadius.circular(
                                              8.0,
                                            ),
                                            border: Border.all(
                                              color: !hasData
                                                  ? Colors.grey.shade200
                                                  : (isNewest
                                                        ? (inMotion
                                                              ? Colors
                                                                    .green
                                                                    .shade700
                                                              : Colors
                                                                    .blue
                                                                    .shade600)
                                                        : (inMotion
                                                              ? Colors
                                                                    .green
                                                                    .shade300
                                                              : Colors
                                                                    .grey
                                                                    .shade300)),
                                              width: isNewest ? 1.5 : 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 44.0,
                                                    child: isNewest
                                                        ? Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      4.0,
                                                                  vertical: 1.5,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: inMotion
                                                                  ? Colors
                                                                        .green
                                                                        .shade600
                                                                  : Colors
                                                                        .blue
                                                                        .shade600,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    4.0,
                                                                  ),
                                                            ),
                                                            child: const Text(
                                                              'MỚI',
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              style: TextStyle(
                                                                fontSize: 9.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          )
                                                        : Text(
                                                            '#${index + 1}',
                                                            style: TextStyle(
                                                              fontSize: 12.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: hasData
                                                                  ? Colors
                                                                        .grey
                                                                        .shade600
                                                                  : Colors
                                                                        .grey
                                                                        .shade400,
                                                            ),
                                                          ),
                                                  ),
                                                  SizedBox(width: 5.0),
                                                  Text(
                                                    hasData
                                                        ? 'Mẫu ${index + 1}'
                                                        : 'Đang chờ mẫu...',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: isNewest
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      color: hasData
                                                          ? Colors.grey.shade800
                                                          : Colors
                                                                .grey
                                                                .shade400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                width: 90.0,
                                                child: Text(
                                                  hasData
                                                      ? '${mag!.toStringAsFixed(2)} m/s²'
                                                      : '-- m/s²',
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 13.0,
                                                    fontWeight: FontWeight.w700,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                    color: !hasData
                                                        ? Colors.grey.shade400
                                                        : (inMotion
                                                              ? Colors
                                                                    .green
                                                                    .shade800
                                                              : Colors
                                                                    .grey
                                                                    .shade800),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingControlCard() {
    if (_isCountingDown) {
      return _buildCountdownCard();
    }
    if (_isRecording) {
      return _buildActiveRecordingCard();
    }
    return _buildIdleRecordingCard();
  }

  /// Thẻ hiển thị khi đang đếm ngược chờ bắt đầu
  Widget _buildCountdownCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.15),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.shade800,
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                'ĐANG ĐẾM NGƯỢC',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Text(
            '00:${_countdownRemaining.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 40.0,
              fontWeight: FontWeight.w900,
              color: Colors.amber.shade900,
              letterSpacing: 2.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            'Chuẩn bị đặt thiết bị vào vị trí đo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.amber.shade900.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14.0),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40.0,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade800,
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    onPressed: _cancelCountdown,
                    child: const Text(
                      'Hủy',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: SizedBox(
                  height: 40.0,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                    ),
                    onPressed: _skipCountdown,
                    child: const Text(
                      'Ghi ngay',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Thẻ hiển thị khi đang trong quá trình ghi dữ liệu
  Widget _buildActiveRecordingCard() {
    final progress = _autoStopSeconds > 0
        ? (_recordingElapsed.inSeconds / _autoStopSeconds).clamp(0.0, 1.0)
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.1),
            blurRadius: 10.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                'ĐANG GHI DỮ LIỆU',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.red.shade700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Text(
                  '${_detector.recordingBuffer.length} mẫu',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatRecordingTimer(_recordingElapsed),
                style: TextStyle(
                  fontSize: 34.0,
                  fontWeight: FontWeight.w800,
                  color: Colors.red.shade800,
                  letterSpacing: 1.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (_autoStopSeconds > 0) ...[
                const SizedBox(width: 6.0),
                Text(
                  '/ ${_formatRecordingTimer(Duration(seconds: _autoStopSeconds))}',
                  style: TextStyle(
                    fontSize: 17.0,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5.0,
                backgroundColor: Colors.red.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
              ),
            ),
          ],
          const SizedBox(height: 12.0),
          SizedBox(
            width: double.infinity,
            height: 44.0,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              onPressed: _isSaving ? null : _stopRecording,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.stop_rounded, size: 20),
              label: Text(
                _isSaving ? 'Đang lưu...' : 'Dừng và Lưu phiên',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ hiển thị khi chưa ghi, cho phép chọn cấu hình và bắt đầu
  Widget _buildIdleRecordingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10.0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                'Ghi dữ liệu',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          // Hàng cài đặt hẹn giờ
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: _showStartDelayPicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: 4.0,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 17,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bắt đầu sau',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  _formatDelayLabel(_startDelaySeconds),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 6.0),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: _showAutoStopPicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: 4.0,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timelapse_outlined,
                            size: 17,
                            color: Colors.purple.shade700,
                          ),
                          const SizedBox(width: 6.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tự dừng sau',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  _formatAutoStopLabel(_autoStopSeconds),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12.0),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 42.0,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    onPressed: _onPressStartRecording,
                    icon: const Icon(Icons.fiber_manual_record, size: 16),
                    label: Text(
                      _startDelaySeconds > 0
                          ? 'Bắt đầu (${_startDelaySeconds}s)'
                          : 'Bắt đầu ghi',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 42.0,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade800,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RecordingHistoryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text(
                      'Lịch sử',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStartDelayPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = [
          (0, 'Bắt đầu ngay'),
          (3, '3 giây'),
          (5, '5 giây'),
          (10, '10 giây'),
          (15, '15 giây'),
          (30, '30 giây'),
        ];

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hẹn giờ bắt đầu',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final opt = options[index];
                        final isSelected = _startDelaySeconds == opt.$1;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 2.0),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.shade50 : null,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 0.0,
                            ),
                            leading: Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                            title: Text(
                              opt.$2,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.blue.shade700
                                    : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _startDelaySeconds = opt.$1;
                              });
                              Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAutoStopPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final options = [
          (0, 'Thủ công (Không giới hạn)'),
          (3, '3 giây'),
          (5, '5 giây'),
          (10, '10 giây'),
          (30, '30 giây'),
          (60, '1 phút'),
          (120, '2 phút'),
          (300, '5 phút'),
          (600, '10 phút'),
        ];

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tự động dừng ghi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final opt = options[index];
                        final isSelected = _autoStopSeconds == opt.$1;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 2.0),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.purple.shade50 : null,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 0.0,
                            ),
                            leading: Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? Colors.purple.shade700
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                            title: Text(
                              opt.$2,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.purple.shade700
                                    : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _autoStopSeconds = opt.$1;
                              });
                              Navigator.pop(ctx);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
