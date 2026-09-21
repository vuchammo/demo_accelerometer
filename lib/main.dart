import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'foreground_service_manager.dart';
import 'gravity_filter.dart';
import 'notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: MotionDetectorView()),
    ),
  );
}

class MotionDetector {
  MotionDetector({
    this.thresholdMin = 0.6,
    this.thresholdMax = 5.0,
    this.requiredConsecutivePoints = 6,
    double timeConstant = 0.3,
    bool initialMoving = false,
  }) : _isMoving = initialMoving,
       _gravityFilter = GravityFilter();

  final double thresholdMin;
  final double thresholdMax;
  final int requiredConsecutivePoints;
  final GravityFilter _gravityFilter;

  final List<double> _recentMagnitudes = [];
  List<double> get recentMagnitudes => List.unmodifiable(_recentMagnitudes);

  bool _isMoving;
  bool get isMoving => _isMoving;

  int _consecutiveHighCount = 0;
  int get consecutiveHighCount => _consecutiveHighCount;

  int _consecutiveLowCount = 0;
  int get consecutiveLowCount => _consecutiveLowCount;

  GravityFilter get gravityFilter => _gravityFilter;

  bool addSample(double x, double y, double z, DateTime time) {
    final linear = _gravityFilter.filter(x, y, z, time);

    _recentMagnitudes.insert(0, linear.magnitude);
    if (_recentMagnitudes.length > 10) {
      _recentMagnitudes.removeLast();
    }

    debugPrint(
      'magnitude: ${linear.magnitude.toStringAsFixed(2)} | '
      'alpha: ${linear.alpha.toStringAsFixed(3)} | '
      'gravity: (${linear.gravityX.toStringAsFixed(1)}, ${linear.gravityY.toStringAsFixed(1)}, ${linear.gravityZ.toStringAsFixed(1)}) | '
      'time: $time',
    );

    return addMagnitudeSample(linear.magnitude);
  }

  bool addMagnitudeSample(double magnitude) {
    bool stateChanged = false;

    if (magnitude >= thresholdMin && magnitude <= thresholdMax) {
      _consecutiveHighCount++;

      _consecutiveLowCount = 0;

      if (_consecutiveHighCount >= requiredConsecutivePoints && !_isMoving) {
        _isMoving = true;
        stateChanged = true;
      }
    } else if (magnitude < thresholdMin) {
      _consecutiveLowCount++;

      _consecutiveHighCount = 0;

      if (_consecutiveLowCount >= requiredConsecutivePoints && _isMoving) {
        _isMoving = false;
        stateChanged = true;
      }
    } else {
      _consecutiveHighCount = 0;
      _consecutiveLowCount = 0;
    }
    return stateChanged;
  }

  void reset() {
    _consecutiveHighCount = 0;
    _consecutiveLowCount = 0;
    _isMoving = false;
    _recentMagnitudes.clear();
    _gravityFilter.reset();
  }
}

class MotionDetectorView extends StatefulWidget {
  const MotionDetectorView({super.key});

  @override
  State<MotionDetectorView> createState() => _MotionDetectorViewState();
}

class _MotionDetectorViewState extends State<MotionDetectorView> {
  final MotionDetector _detector = MotionDetector();

  StreamSubscription<AccelerometerEvent>? _subscription;
  static const Duration _sampleInterval = Duration(milliseconds: 500);

  DateTime _stateChangedTime = DateTime.now();
  Timer? _clockTimer;

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
    _subscription = accelerometerEventStream(samplingPeriod: _sampleInterval)
        .throttleTime(const Duration(milliseconds: 350))
        .listen(
          (AccelerometerEvent event) {
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

  @override
  void dispose() {
    _clockTimer?.cancel();
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

    return WithForegroundTask(
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
                const SizedBox(height: 18.0),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 16.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '10 Magnitude gần nhất',
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
                              borderRadius: BorderRadius.circular(8.0),
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
                              index < _detector.recentMagnitudes.length;
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
                            margin: const EdgeInsets.only(bottom: 5.0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                            ),
                            decoration: BoxDecoration(
                              color: !hasData
                                  ? Colors.grey.shade50
                                  : (inMotion
                                        ? Colors.green.shade50
                                        : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: !hasData
                                    ? Colors.grey.shade200
                                    : (isNewest
                                          ? (inMotion
                                                ? Colors.green.shade700
                                                : Colors.blue.shade600)
                                          : (inMotion
                                                ? Colors.green.shade300
                                                : Colors.grey.shade300)),
                                width: isNewest ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 44.0,
                                      child: isNewest
                                          ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4.0,
                                                    vertical: 1.5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: inMotion
                                                    ? Colors.green.shade600
                                                    : Colors.blue.shade600,
                                                borderRadius:
                                                    BorderRadius.circular(4.0),
                                              ),
                                              child: const Text(
                                                'MỚI',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 9.0,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )
                                          : Text(
                                              '#${index + 1}',
                                              style: TextStyle(
                                                fontSize: 12.0,
                                                fontWeight: FontWeight.w600,
                                                color: hasData
                                                    ? Colors.grey.shade600
                                                    : Colors.grey.shade400,
                                              ),
                                            ),
                                    ),
                                    Text(
                                      hasData
                                          ? 'Mẫu #${index + 1}'
                                          : 'Đang chờ mẫu...',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isNewest
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: hasData
                                            ? Colors.grey.shade800
                                            : Colors.grey.shade400,
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
                                                ? Colors.green.shade800
                                                : Colors.grey.shade800),
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
