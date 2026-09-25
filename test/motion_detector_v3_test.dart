import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_accelerometer/motion_detector.dart';

void main() {
  group('Motion Detector v3 Tests', () {
    test('MotionConfig has correct v3 default parameters', () {
      const config = MotionConfig();
      expect(config.sampleRateHz, 12.5);
      expect(config.windowSamples, 50);
      expect(config.hopSamples, 6);
      expect(config.envSamples, 10);
      expect(config.hpSamples, 10);
      expect(config.lagLo, 3);
      expect(config.lagHi, 18);
      expect(config.cvMax, 0.30);
      expect(config.meanMin, 0.30);
      expect(config.peakMin, 0.20);
      expect(config.majorityWindow, 10);
      expect(config.majorityFrac, 0.5);
      expect(config.sessionRatio, 0.5);
      expect(config.skipSeconds, 1.5);
    });

    test('Still signal (near zero noise) is classified as NOT MOVING', () {
      final t = <double>[];
      final mag = <double>[];
      // 10 seconds of very low noise around 0.05
      for (int i = 0; i < 125; i++) {
        t.add(i / 12.5);
        mag.add(0.05 + 0.01 * math.sin(i.toDouble()));
      }

      final result = MotionDetector.classifySession(t, mag);
      expect(result.isMoving, isFalse);
      expect(result.ratio, 0.0);
    });

    test('Walking signal with periodic oscillation has high peak and is classified as MOVING', () {
      final t = <double>[];
      final mag = <double>[];
      // 10 seconds of periodic walking motion at ~1.8 Hz (sinusoidal) with mean ~1.5
      // Sample rate = 12.5 Hz, Period = 12.5 / 1.8 ≈ 7 samples (within lagLo 3 .. lagHi 18)
      for (int i = 0; i < 125; i++) {
        final sec = i / 12.5;
        t.add(sec);
        // periodic rhythm: mean 1.5, amplitude 0.8
        mag.add(1.5 + 0.8 * math.sin(2 * math.pi * 1.8 * sec));
      }

      final result = MotionDetector.classifySession(t, mag);
      expect(result.isMoving, isTrue);
      expect(result.ratio, greaterThanOrEqualTo(0.5));
    });

    test('Streaming add produces MotionWindow with peak property', () {
      final detector = MotionDetector();
      final windows = <MotionWindow>[];

      for (int i = 0; i < 60; i++) {
        final sec = i / 12.5;
        final val = 1.2 + 0.5 * math.sin(2 * math.pi * 1.5 * sec);
        final w = detector.add(sec, val);
        windows.addAll(w);
      }

      expect(windows, isNotEmpty);
      final last = windows.last;
      expect(last.peak, isNotNull);
      expect(last.peak, greaterThan(0.0));
      expect(detector.lastWindow, isNotNull);
    });
  });
}
