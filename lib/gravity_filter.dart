import 'dart:math' as math;

class LinearAcceleration {
  const LinearAcceleration({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.gravityX,
    required this.gravityY,
    required this.gravityZ,
    required this.alpha,
  });

  final double x;
  final double y;
  final double z;
  final double magnitude;

  final double gravityX;
  final double gravityY;
  final double gravityZ;

  final double alpha;

  @override
  String toString() =>
      'LinearAcceleration(x: ${x.toStringAsFixed(2)}, y: ${y.toStringAsFixed(2)}, z: ${z.toStringAsFixed(2)}, mag: ${magnitude.toStringAsFixed(2)}, alpha: ${alpha.toStringAsFixed(3)})';
}

class GravityFilter {
  GravityFilter();

  double timeConstant = 1.2;

  double _gravityX = 0;
  double _gravityY = 0;
  double _gravityZ = 0;

  DateTime? _lastTimestamp;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  double get gravityX => _gravityX;
  double get gravityY => _gravityY;
  double get gravityZ => _gravityZ;

  LinearAcceleration filter(
    double rawX,
    double rawY,
    double rawZ, [
    DateTime? timestamp,
  ]) {
    final now = timestamp ?? DateTime.now();

    if (!_isInitialized || _lastTimestamp == null) {
      _gravityX = rawX;
      _gravityY = rawY;
      _gravityZ = rawZ;
      _lastTimestamp = now;
      _isInitialized = true;

      return LinearAcceleration(
        x: 0.0,
        y: 0.0,
        z: 0.0,
        magnitude: 0.0,
        gravityX: _gravityX,
        gravityY: _gravityY,
        gravityZ: _gravityZ,
        alpha: 1.0,
      );
    }

    final diffMicros = now.difference(_lastTimestamp!).inMicroseconds;

    final dT = diffMicros / 1000000.0;
    _lastTimestamp = now;

    final currentAlpha = timeConstant / (timeConstant + dT);

    _gravityX = currentAlpha * _gravityX + (1 - currentAlpha) * rawX;
    _gravityY = currentAlpha * _gravityY + (1 - currentAlpha) * rawY;
    _gravityZ = currentAlpha * _gravityZ + (1 - currentAlpha) * rawZ;

    final linearX = rawX - _gravityX;
    final linearY = rawY - _gravityY;
    final linearZ = rawZ - _gravityZ;

    final magnitude = math.sqrt(
      linearX * linearX + linearY * linearY + linearZ * linearZ,
    );

    return LinearAcceleration(
      x: linearX,
      y: linearY,
      z: linearZ,
      magnitude: magnitude,
      gravityX: _gravityX,
      gravityY: _gravityY,
      gravityZ: _gravityZ,
      alpha: currentAlpha,
    );
  }

  void reset() {
    _gravityX = 0;
    _gravityY = 0;
    _gravityZ = 0;
    _lastTimestamp = null;
    _isInitialized = false;
  }
}
