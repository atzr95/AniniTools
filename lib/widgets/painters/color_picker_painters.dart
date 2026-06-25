import 'package:flutter/material.dart';

/// Custom painter for color palette (saturation/value picker)
class ColorPalettePainter extends CustomPainter {
  final double hue;

  ColorPalettePainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Create horizontal gradient (saturation: 0 to 1)
    final saturationGradient = LinearGradient(
      colors: [Colors.white, HSVColor.fromAHSV(1, hue, 1, 1).toColor()],
    );

    // Create vertical gradient (value: 1 to 0)
    final valueGradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0x00000000), // Transparent
        Colors.black,
      ],
    );

    // Draw saturation gradient
    canvas.drawRect(
      rect,
      Paint()..shader = saturationGradient.createShader(rect),
    );

    // Draw value gradient on top
    canvas.drawRect(rect, Paint()..shader = valueGradient.createShader(rect));
  }

  @override
  bool shouldRepaint(ColorPalettePainter oldDelegate) {
    return oldDelegate.hue != hue;
  }
}

/// Custom painter for hue slider
class HueSliderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Create rainbow gradient (all hues)
    final hueGradient = LinearGradient(
      colors: [
        const HSVColor.fromAHSV(1, 0, 1, 1).toColor(), // Red
        const HSVColor.fromAHSV(1, 60, 1, 1).toColor(), // Yellow
        const HSVColor.fromAHSV(1, 120, 1, 1).toColor(), // Green
        const HSVColor.fromAHSV(1, 180, 1, 1).toColor(), // Cyan
        const HSVColor.fromAHSV(1, 240, 1, 1).toColor(), // Blue
        const HSVColor.fromAHSV(1, 300, 1, 1).toColor(), // Magenta
        const HSVColor.fromAHSV(1, 360, 1, 1).toColor(), // Red
      ],
    );

    canvas.drawRect(rect, Paint()..shader = hueGradient.createShader(rect));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
