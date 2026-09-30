import 'dart:math' as math;

/// A three-axis sensor sample with its precomputed magnitude.
/// Shared by the accelerometer, gyroscope and linear acceleration services.
class Vector3Reading {
  final double x;
  final double y;
  final double z;
  final double magnitude;

  Vector3Reading(this.x, this.y, this.z)
    : magnitude = math.sqrt(x * x + y * y + z * z);
}
