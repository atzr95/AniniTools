import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/bitmap_fonts.dart';
import '../../models/text_style_config.dart';
import 'text_style_renderer.dart';

/// LED Matrix style text renderer.
/// Renders text as a grid of dots similar to LED scoreboards.
class LEDMatrixRenderer extends TextStyleRenderer {
  final LEDMatrixConfig config;

  LEDMatrixRenderer({this.config = const LEDMatrixConfig()});

  @override
  Widget build({
    required BuildContext context,
    required String text,
    required Color primaryColor,
    List<Color>? gradientColors,
    double fontSize = 48.0,
    double? animationProgress,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: LEDMatrixPainter(
            text: text,
            primaryColor: primaryColor,
            gradientColors: gradientColors,
            config: config,
            animationProgress: animationProgress ?? 1.0,
          ),
        );
      },
    );
  }
}

/// CustomPainter that renders text as an LED dot matrix.
class LEDMatrixPainter extends CustomPainter {
  final String text;
  final Color primaryColor;
  final List<Color>? gradientColors;
  final LEDMatrixConfig config;
  final double animationProgress;

  LEDMatrixPainter({
    required this.text,
    required this.primaryColor,
    this.gradientColors,
    required this.config,
    this.animationProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final dotSize = config.dotSize.pixels;
    final spacing = config.dotSpacing.pixels;
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

      // Calculate animation visibility for this character
      final charVisible = _isCharVisible(charIndex, text.length);

      for (int row = 0; row < charHeight; row++) {
        for (int col = 0; col < charWidth; col++) {
          final isLit = BitmapFonts.isDotLit(char, row, col);
          final dotX = charStartX + col * scaledTotalDotSize;
          final dotY = startY + row * scaledTotalDotSize;

          // Calculate animation visibility for this dot
          final dotVisible =
              charVisible && _isDotVisible(charIndex, row, col, text.length);

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
            dotColor = _getGradientColor(gradientPos, gradientColors!);
          } else {
            dotColor = primaryColor;
          }

          // Set paint color
          if (isLit && dotVisible) {
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

  /// Check if a character should be visible based on animation
  bool _isCharVisible(int charIndex, int totalChars) {
    if (animationProgress >= 1.0 ||
        config.animation == LEDAnimation.none) {
      return true;
    }

    switch (config.animation) {
      case LEDAnimation.typewriter:
        final threshold = (charIndex + 1) / totalChars;
        return animationProgress >= threshold;
      case LEDAnimation.scan:
      case LEDAnimation.randomFill:
        return true; // Handled at dot level
      case LEDAnimation.none:
        return true;
    }
  }

  /// Check if a specific dot should be visible based on animation
  bool _isDotVisible(int charIndex, int row, int col, int totalChars) {
    if (animationProgress >= 1.0 ||
        config.animation == LEDAnimation.none) {
      return true;
    }

    switch (config.animation) {
      case LEDAnimation.scan:
        // Horizontal scan from left to right
        final totalCols =
            totalChars * BitmapFonts.charWidth + (totalChars - 1);
        final currentCol = charIndex * (BitmapFonts.charWidth + 1) + col;
        final threshold = currentCol / totalCols;
        return animationProgress >= threshold;

      case LEDAnimation.randomFill:
        // Use a seeded random based on position for consistent animation
        final seed = charIndex * 100 + row * 10 + col;
        final random = math.Random(seed);
        final threshold = random.nextDouble();
        return animationProgress >= threshold;

      case LEDAnimation.typewriter:
      case LEDAnimation.none:
        return true;
    }
  }

  /// Interpolate color from gradient based on position (0.0 - 1.0)
  Color _getGradientColor(double position, List<Color> colors) {
    if (colors.length < 2) return colors.first;
    if (position <= 0) return colors.first;
    if (position >= 1) return colors.last;

    final scaledPos = position * (colors.length - 1);
    final lowerIndex = scaledPos.floor();
    final upperIndex = (lowerIndex + 1).clamp(0, colors.length - 1);
    final t = scaledPos - lowerIndex;

    return Color.lerp(colors[lowerIndex], colors[upperIndex], t)!;
  }

  @override
  bool shouldRepaint(LEDMatrixPainter oldDelegate) {
    return text != oldDelegate.text ||
        primaryColor != oldDelegate.primaryColor ||
        gradientColors != oldDelegate.gradientColors ||
        config != oldDelegate.config ||
        animationProgress != oldDelegate.animationProgress;
  }
}

/// Widget wrapper for LED Matrix with optional animation
class LEDMatrixText extends StatefulWidget {
  final String text;
  final Color primaryColor;
  final List<Color>? gradientColors;
  final LEDMatrixConfig config;
  final bool animate;

  const LEDMatrixText({
    super.key,
    required this.text,
    required this.primaryColor,
    this.gradientColors,
    this.config = const LEDMatrixConfig(),
    this.animate = false,
  });

  @override
  State<LEDMatrixText> createState() => _LEDMatrixTextState();
}

class _LEDMatrixTextState extends State<LEDMatrixText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _getAnimationDuration(),
    );

    if (widget.animate && widget.config.animation != LEDAnimation.none) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  Duration _getAnimationDuration() {
    switch (widget.config.animation) {
      case LEDAnimation.typewriter:
        return Duration(milliseconds: widget.text.length * 100);
      case LEDAnimation.scan:
        return const Duration(milliseconds: 1500);
      case LEDAnimation.randomFill:
        return const Duration(milliseconds: 1000);
      case LEDAnimation.none:
        return Duration.zero;
    }
  }

  @override
  void didUpdateWidget(LEDMatrixText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text ||
        widget.config.animation != oldWidget.config.animation) {
      _controller.duration = _getAnimationDuration();
      if (widget.animate && widget.config.animation != LEDAnimation.none) {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: LEDMatrixPainter(
            text: widget.text,
            primaryColor: widget.primaryColor,
            gradientColors: widget.gradientColors,
            config: widget.config,
            animationProgress: _controller.value,
          ),
        );
      },
    );
  }
}
