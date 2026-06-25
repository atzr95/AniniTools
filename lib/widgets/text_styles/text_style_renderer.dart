import 'package:flutter/material.dart';

/// Base class for text style renderers.
/// Each style (LED, Neon, etc.) implements this to provide custom rendering.
abstract class TextStyleRenderer {
  /// Build the widget that renders the styled text
  Widget build({
    required BuildContext context,
    required String text,
    required Color primaryColor,
    List<Color>? gradientColors,
    double fontSize = 48.0,
    double? animationProgress,
  });

  /// Clean up any resources
  void dispose() {}
}
