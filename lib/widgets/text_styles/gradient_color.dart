import 'package:flutter/material.dart';

/// Interpolate a color from a gradient list based on position (0.0 - 1.0).
Color getGradientColor(double position, List<Color> colors) {
  if (colors.length < 2) return colors.first;
  if (position <= 0) return colors.first;
  if (position >= 1) return colors.last;

  final scaledPos = position * (colors.length - 1);
  final lowerIndex = scaledPos.floor();
  final upperIndex = (lowerIndex + 1).clamp(0, colors.length - 1);
  final t = scaledPos - lowerIndex;

  return Color.lerp(colors[lowerIndex], colors[upperIndex], t)!;
}
