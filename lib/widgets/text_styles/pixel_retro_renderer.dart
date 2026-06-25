import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/bitmap_fonts.dart';
import '../../models/text_style_config.dart';

/// Pixel/Retro style text renderer.
/// Renders text with blocky pixels like old CRT displays and retro games.
class PixelRetroRenderer {
  final PixelRetroConfig config;

  PixelRetroRenderer({this.config = const PixelRetroConfig()});

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
          painter: PixelRetroPainter(
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

/// CustomPainter that renders text as blocky pixels with retro effects.
class PixelRetroPainter extends CustomPainter {
  final String text;
  final Color primaryColor;
  final List<Color>? gradientColors;
  final PixelRetroConfig config;
  final double animationProgress;

  PixelRetroPainter({
    required this.text,
    required this.primaryColor,
    this.gradientColors,
    required this.config,
    this.animationProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final pixelSize = config.pixelSize.pixels;

    // Calculate character dimensions in pixels
    const charWidth = BitmapFonts.charWidth;
    const charHeight = BitmapFonts.charHeight;
    const charSpacing = 1; // Pixels between characters

    // Calculate total text width in pixels
    final textWidthPixels =
        text.length * charWidth + (text.length - 1) * charSpacing;
    final textHeightPixels = charHeight;

    // Calculate pixel dimensions
    final textWidthPx = textWidthPixels * pixelSize;
    final textHeightPx = textHeightPixels * pixelSize;

    // Calculate scale to fit within available space with padding
    final availableWidth = size.width * 0.95;
    final availableHeight = size.height * 0.8;
    final scaleX = availableWidth / textWidthPx;
    final scaleY = availableHeight / textHeightPx;
    final scale = math.min(scaleX, scaleY);

    // Clamp scale to reasonable bounds
    final finalScale = scale.clamp(0.5, 4.0);

    // Calculate scaled dimensions
    final scaledPixelSize = pixelSize * finalScale;

    // Calculate starting position (centered)
    final scaledTextWidth = textWidthPixels * scaledPixelSize;
    final scaledTextHeight = textHeightPixels * scaledPixelSize;
    final startX = (size.width - scaledTextWidth) / 2;
    final startY = (size.height - scaledTextHeight) / 2;

    // Draw CRT curve effect (vignette) if enabled
    if (config.showCrtCurve) {
      _drawCrtCurve(canvas, size);
    }

    // Prepare paint
    final pixelPaint = Paint()..style = PaintingStyle.fill;

    // Draw each character
    double charStartX = startX;
    for (int charIndex = 0; charIndex < text.length; charIndex++) {
      final char = text[charIndex];

      // Calculate animation visibility (glitch effect)
      final isVisible = _isCharVisible(charIndex);

      for (int row = 0; row < charHeight; row++) {
        for (int col = 0; col < charWidth; col++) {
          final isLit = BitmapFonts.isDotLit(char, row, col);

          if (isLit && isVisible) {
            final pixelX = charStartX + col * scaledPixelSize;
            final pixelY = startY + row * scaledPixelSize;

            // Determine color
            Color pixelColor;
            if (gradientColors != null && gradientColors!.length >= 2) {
              final gradientPos =
                  (charIndex * charWidth + col) / (textWidthPixels - 1);
              pixelColor = _getGradientColor(gradientPos, gradientColors!);
            } else {
              pixelColor = primaryColor;
            }

            // Apply chroma shift effect if enabled
            if (config.chromaShift) {
              _drawChromaShiftPixel(
                canvas,
                pixelX,
                pixelY,
                scaledPixelSize,
                pixelColor,
              );
            } else {
              pixelPaint.color = pixelColor;
              canvas.drawRect(
                Rect.fromLTWH(pixelX, pixelY, scaledPixelSize, scaledPixelSize),
                pixelPaint,
              );
            }
          }
        }
      }

      charStartX += (charWidth + charSpacing) * scaledPixelSize;
    }

    // Draw scanlines overlay if enabled
    if (config.showScanlines) {
      _drawScanlines(canvas, size, startY, scaledTextHeight);
    }
  }

  void _drawChromaShiftPixel(
    Canvas canvas,
    double x,
    double y,
    double size,
    Color color,
  ) {
    final paint = Paint()..style = PaintingStyle.fill;
    final shift = size * 0.15; // Amount of RGB shift

    // Red channel (shifted left)
    paint.color = Color.fromARGB(
      (color.a * 255).round(),
      255,
      0,
      0,
    ).withValues(alpha: 0.7);
    canvas.drawRect(
      Rect.fromLTWH(x - shift, y, size, size),
      paint,
    );

    // Green channel (center)
    paint.color = Color.fromARGB(
      (color.a * 255).round(),
      0,
      255,
      0,
    ).withValues(alpha: 0.7);
    canvas.drawRect(
      Rect.fromLTWH(x, y, size, size),
      paint,
    );

    // Blue channel (shifted right)
    paint.color = Color.fromARGB(
      (color.a * 255).round(),
      0,
      0,
      255,
    ).withValues(alpha: 0.7);
    canvas.drawRect(
      Rect.fromLTWH(x + shift, y, size, size),
      paint,
    );

    // Main color overlay
    paint.color = color.withValues(alpha: 0.5);
    canvas.drawRect(
      Rect.fromLTWH(x, y, size, size),
      paint,
    );
  }

  void _drawScanlines(
      Canvas canvas, Size size, double textStartY, double textHeight) {
    final scanlinePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: config.scanlineOpacity);

    // Draw horizontal scanlines across the entire width
    final scanlineHeight = 1.0;
    final scanlineSpacing = 3.0;

    for (double y = 0; y < size.height; y += scanlineSpacing) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, scanlineHeight),
        scanlinePaint,
      );
    }
  }

  void _drawCrtCurve(Canvas canvas, Size size) {
    // Create a radial gradient vignette effect
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height) * 0.7;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.3),
          Colors.black.withValues(alpha: 0.6),
        ],
        stops: const [0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  bool _isCharVisible(int charIndex) {
    if (animationProgress >= 1.0 ||
        config.animation == PixelAnimation.none) {
      return true;
    }

    if (config.animation == PixelAnimation.glitch) {
      // Random glitch effect based on animation progress
      final threshold = (charIndex + 1) / text.length;
      final random = math.sin(charIndex * 12.9898 + animationProgress * 78.233);
      return animationProgress >= threshold || random > 0.3;
    }

    return true;
  }

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
  bool shouldRepaint(PixelRetroPainter oldDelegate) {
    return text != oldDelegate.text ||
        primaryColor != oldDelegate.primaryColor ||
        gradientColors != oldDelegate.gradientColors ||
        config != oldDelegate.config ||
        animationProgress != oldDelegate.animationProgress;
  }
}

/// Widget wrapper for Pixel/Retro with optional animation
class PixelRetroText extends StatefulWidget {
  final String text;
  final Color primaryColor;
  final List<Color>? gradientColors;
  final PixelRetroConfig config;
  final bool animate;

  const PixelRetroText({
    super.key,
    required this.text,
    required this.primaryColor,
    this.gradientColors,
    this.config = const PixelRetroConfig(),
    this.animate = false,
  });

  @override
  State<PixelRetroText> createState() => _PixelRetroTextState();
}

class _PixelRetroTextState extends State<PixelRetroText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _getAnimationDuration(),
    );

    if (widget.animate && widget.config.animation != PixelAnimation.none) {
      if (widget.config.animation == PixelAnimation.crtFlicker) {
        _controller.repeat(reverse: true);
      } else {
        _controller.forward();
      }
    } else {
      _controller.value = 1.0;
    }
  }

  Duration _getAnimationDuration() {
    switch (widget.config.animation) {
      case PixelAnimation.crtFlicker:
        return const Duration(milliseconds: 100);
      case PixelAnimation.glitch:
        return Duration(milliseconds: widget.text.length * 50);
      case PixelAnimation.none:
        return Duration.zero;
    }
  }

  @override
  void didUpdateWidget(PixelRetroText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text ||
        widget.config.animation != oldWidget.config.animation) {
      _controller.duration = _getAnimationDuration();
      if (widget.animate && widget.config.animation != PixelAnimation.none) {
        if (widget.config.animation == PixelAnimation.crtFlicker) {
          _controller.repeat(reverse: true);
        } else {
          _controller.forward(from: 0);
        }
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
          painter: PixelRetroPainter(
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
