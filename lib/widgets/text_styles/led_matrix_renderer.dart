import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/bitmap_fonts.dart';
import '../../models/text_style_config.dart';
import 'gradient_color.dart';

/// CustomPainter that renders text as an LED dot matrix.
class LEDMatrixPainter extends CustomPainter {
  final String text;
  final Color primaryColor;
  final List<Color>? gradientColors;
  final LEDMatrixConfig config;

  LEDMatrixPainter({
    required this.text,
    required this.primaryColor,
    this.gradientColors,
    required this.config,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final dotSize = config.dotSize.pixels;
    const spacing = 2.0;
    final totalDotSize = dotSize + spacing;

    // Calculate character dimensions in dots
    const charWidth = BitmapFonts.charWidth;
    const charHeight = BitmapFonts.charHeight;
    const charSpacing = 1; // Dots between characters

    // Calculate total text width in dots
    final textWidthDots =
        text.length * charWidth + (text.length - 1) * charSpacing;
    final textHeightDots = charHeight;

    // Calculate pixel dimensions
    final textWidthPx = textWidthDots * totalDotSize - spacing;
    final textHeightPx = textHeightDots * totalDotSize - spacing;

    // Calculate scale to fit within available space with padding
    final availableWidth = size.width * 0.95;
    final availableHeight = size.height * 0.8;
    final scaleX = availableWidth / textWidthPx;
    final scaleY = availableHeight / textHeightPx;
    final scale = math.min(scaleX, scaleY);

    // Clamp scale to reasonable bounds
    final finalScale = scale.clamp(0.5, 3.0);

    // Calculate scaled dimensions
    final scaledDotSize = dotSize * finalScale;
    final scaledSpacing = spacing * finalScale;
    final scaledTotalDotSize = scaledDotSize + scaledSpacing;

    // Calculate starting position (centered)
    final scaledTextWidth = textWidthDots * scaledTotalDotSize - scaledSpacing;
    final scaledTextHeight =
        textHeightDots * scaledTotalDotSize - scaledSpacing;
    final startX = (size.width - scaledTextWidth) / 2;
    final startY = (size.height - scaledTextHeight) / 2;

    // Prepare paints
    final litPaint = Paint()..style = PaintingStyle.fill;
    final unlitPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = primaryColor.withValues(alpha: config.unlitOpacity);

    // Draw each character
    double charStartX = startX;
    for (int charIndex = 0; charIndex < text.length; charIndex++) {
      final char = text[charIndex];

      for (int row = 0; row < charHeight; row++) {
        for (int col = 0; col < charWidth; col++) {
          final isLit = BitmapFonts.isDotLit(char, row, col);
          final dotX = charStartX + col * scaledTotalDotSize;
          final dotY = startY + row * scaledTotalDotSize;

          // Determine color
          Color dotColor;

          // Check for emoji color first (if enabled)
          final emojiColor = config.useEmojiColors
              ? BitmapFonts.getEmojiColor(char)
              : null;

          if (emojiColor != null) {
            // Use the emoji's natural color
            dotColor = emojiColor;
          } else if (gradientColors != null && gradientColors!.length >= 2) {
            // Calculate gradient position based on horizontal position
            final gradientPos =
                (charIndex * charWidth + col) / (textWidthDots - 1);
            dotColor = getGradientColor(gradientPos, gradientColors!);
          } else {
            dotColor = primaryColor;
          }

          // Set paint color
          if (isLit) {
            litPaint.color = dotColor;
            _drawDot(canvas, dotX, dotY, scaledDotSize, litPaint);
          } else if (config.unlitOpacity > 0) {
            unlitPaint.color = dotColor.withValues(alpha: config.unlitOpacity);
            _drawDot(canvas, dotX, dotY, scaledDotSize, unlitPaint);
          }
        }
      }

      // Move to next character position
      charStartX += (charWidth + charSpacing) * scaledTotalDotSize;
    }
  }

  /// Draw a single dot based on the configured shape
  void _drawDot(Canvas canvas, double x, double y, double size, Paint paint) {
    final center = Offset(x + size / 2, y + size / 2);
    final radius = size / 2;

    switch (config.dotShape) {
      case LEDDotShape.circle:
        canvas.drawCircle(center, radius, paint);
        break;
      case LEDDotShape.square:
        canvas.drawRect(
          Rect.fromLTWH(x, y, size, size),
          paint,
        );
        break;
      case LEDDotShape.roundedSquare:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, size, size),
            Radius.circular(radius * 0.3),
          ),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(LEDMatrixPainter oldDelegate) {
    return text != oldDelegate.text ||
        primaryColor != oldDelegate.primaryColor ||
        gradientColors != oldDelegate.gradientColors ||
        config != oldDelegate.config;
  }
}
