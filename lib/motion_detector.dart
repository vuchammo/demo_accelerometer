import 'package:demo_accelerometer/gravity_filter.dart';
import 'package:flutter/material.dart';

class MotionDetector {
  MotionDetector() : _gravityFilter = GravityFilter();

  final double thresholdMin = 1.0;
  final double thresholdMax = 5.0;
  final int requiredConsecutivePoints = 5;
  final GravityFilter _gravityFilter;

  final List<double> _recentMagnitudes = [];
  List<double> get recentMagnitudes => List.unmodifiable(_recentMagnitudes);

  bool _isMoving = false;
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
