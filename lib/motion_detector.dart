import 'dart:math';

import 'package:flutter/material.dart';

class MotionDetector {
  final double thresholdMin = 1.0;
  final double thresholdMax = 5.0;
  final int requiredConsecutivePoints = 18;

  final List<double> _recentMagnitudes = [];
  List<double> get recentMagnitudes => List.unmodifiable(_recentMagnitudes);

  bool _isMoving = false;
  bool get isMoving => _isMoving;

  int _consecutiveHighCount = 0;
  int get consecutiveHighCount => _consecutiveHighCount;

  int _consecutiveLowCount = 0;
  int get consecutiveLowCount => _consecutiveLowCount;

  bool addSample(double x, double y, double z, DateTime time) {
    final magnitude = sqrt(x * x + y * y + z * z);

    _recentMagnitudes.insert(0, magnitude);
    if (_recentMagnitudes.length > 10) {
      _recentMagnitudes.removeLast();
    }

    debugPrint(
      'magnitude: ${magnitude.toStringAsFixed(2)} | '
      'time: $time',
    );

    return addMagnitudeSample(magnitude);
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
  }
}
