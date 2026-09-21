import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'gravity_filter.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: MotionDetectorView()),
    ),
  );
}

class MotionDetector {
  MotionDetector({
    this.thresholdMin = 0.9,
    this.thresholdMax = 5.0,
    this.requiredConsecutivePoints = 5,
    double timeConstant = 0.3,
    double? fixedAlpha,
    bool initialMoving = false,
  }) : _isMoving = initialMoving,
       _gravityFilter = GravityFilter(timeConstant: timeConstant);

  final double thresholdMin;
  final double thresholdMax;
  final int requiredConsecutivePoints;
  final GravityFilter _gravityFilter;

  bool _isMoving;
  bool get isMoving => _isMoving;

  int _consecutiveHighCount = 0;
  int get consecutiveHighCount => _consecutiveHighCount;

  int _consecutiveLowCount = 0;
  int get consecutiveLowCount => _consecutiveLowCount;

  GravityFilter get gravityFilter => _gravityFilter;

  bool addSample(double x, double y, double z, DateTime time) {
    final linear = _gravityFilter.filter(x, y, z, time);

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
    }
    return stateChanged;
  }

  void reset() {
    _consecutiveHighCount = 0;
    _consecutiveLowCount = 0;
    _isMoving = false;
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
              if (mounted) {
                setState(() {});
              }
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
      alpha: 0.4,
    );

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24.0),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 24.0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 40.0,
              vertical: 40.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // const SizedBox(height: 16.0),
                Text(
                  isMoving ? 'Có chuyển động' : 'Không chuyển động',
                  style: const TextStyle(
                    fontSize: 26.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16.0),
                Text(
                  _formatDuration(currentDuration),
                  style: const TextStyle(
                    fontSize: 60.0,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
