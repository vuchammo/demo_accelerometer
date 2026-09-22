import 'dart:math';

import 'package:flutter/material.dart';

class MotionDetector {
  final double thresholdMin = 1.0;
  final double thresholdMax = 8.0;
  static const int windowSize = 30;
  static const int requiredMotionPoints = 28;
  static const int requiredStillPoints = 30;

  final List<double> _recentMagnitudes = [];
  List<double> get recentMagnitudes => List.unmodifiable(_recentMagnitudes);

  final List<double> _magnitudeWindow = [];
  List<double> get magnitudeWindow => List.unmodifiable(_magnitudeWindow);

  bool _isMoving = false;
  bool get isMoving => _isMoving;

  int _motionPointsCount = 0;
  int get motionPointsCount => _motionPointsCount;
  int get consecutiveHighCount => _motionPointsCount;

  int _stillPointsCount = 0;
  int get stillPointsCount => _stillPointsCount;
  int get consecutiveLowCount => _stillPointsCount;

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

    _magnitudeWindow.add(magnitude);

    if (_magnitudeWindow.length > windowSize) {
      _magnitudeWindow.removeAt(0);
    }

    int motionCount = 0;
    int stillCount = 0;

    for (final magnitudeValue in _magnitudeWindow) {
      if (magnitudeValue >= thresholdMin && magnitudeValue <= thresholdMax) {
        motionCount++;
      } else if (magnitudeValue < thresholdMin) {
        stillCount++;
      }
    }

    _motionPointsCount = motionCount;
    _stillPointsCount = stillCount;

    if (!_isMoving) {
      if (motionCount >= requiredMotionPoints) {
        _isMoving = true;
        stateChanged = true;
      }
    } else {
      if (_magnitudeWindow.length >= requiredStillPoints &&
          stillCount >= requiredStillPoints) {
        _isMoving = false;
        stateChanged = true;
      }
    }

    return stateChanged;
  }

  void reset() {
    _motionPointsCount = 0;
    _stillPointsCount = 0;
    _isMoving = false;
    _recentMagnitudes.clear();
    _magnitudeWindow.clear();
  }
}
