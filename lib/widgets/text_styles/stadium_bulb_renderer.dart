import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/bitmap_fonts.dart';
import '../../models/text_style_config.dart';

/// Stadium Bulb style text renderer.
/// Renders text as large theatrical marquee bulbs with sockets.
/// Distinctly different from LED Matrix - these are big, glowing incandescent-style bulbs.
class StadiumBulbRenderer {
  final StadiumBulbConfig config;

  StadiumBulbRenderer({this.config = const StadiumBulbConfig()});

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
          painter: StadiumBulbPainter(
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

/// CustomPainter that renders text as theatrical marquee bulbs.
class StadiumBulbPainter extends CustomPainter {
  final String text;
  final Color primaryColor;
  final List<Color>? gradientColors;
  final StadiumBulbConfig config;
  final double animationProgress;

  StadiumBulbPainter({
    required this.text,
    required this.primaryColor,
    this.gradientColors,
    required this.config,
    this.animationProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final bulbSize = config.bulbSize.pixels;
    final spacing = config.bulbSpacing.pixels;
    // Add extra spacing for sockets
    final socketPadding = config.showSocket ? bulbSize * 0.15 : 0;
    final totalBulbSize = bulbSize + spacing + socketPadding;

    // Calculate character dimensions in bulbs
    const charWidth = BitmapFonts.charWidth;
    const charHeight = BitmapFonts.charHeight;
    const charSpacing = 2; // More spacing between characters for marquee look

    // Calculate total text width in bulbs
    final textWidthBulbs =
        text.length * charWidth + (text.length - 1) * charSpacing;
    final textHeightBulbs = charHeight;

    // Calculate pixel dimensions
    final textWidthPx = textWidthBulbs * totalBulbSize - spacing;
    final textHeightPx = textHeightBulbs * totalBulbSize - spacing;

    // Calculate scale to fit within available space with padding
    final availableWidth = size.width * 0.95;
    final availableHeight = size.height * 0.8;
    final scaleX = availableWidth / textWidthPx;
    final scaleY = availableHeight / textHeightPx;
    final scale = math.min(scaleX, scaleY);

    // Clamp scale to reasonable bounds
    final finalScale = scale.clamp(0.2, 2.0);

    // Calculate scaled dimensions
    final scaledBulbSize = bulbSize * finalScale;
    final scaledSpacing = spacing * finalScale;
    final scaledSocketPadding = socketPadding * finalScale;
    final scaledTotalBulbSize = scaledBulbSize + scaledSpacing + scaledSocketPadding;

    // Calculate starting position (centered)
    final scaledTextWidth = textWidthBulbs * scaledTotalBulbSize - scaledSpacing;
    final scaledTextHeight =
        textHeightBulbs * scaledTotalBulbSize - scaledSpacing;
    final startX = (size.width - scaledTextWidth) / 2;
    final startY = (size.height - scaledTextHeight) / 2;

    // Draw each character
    double charStartX = startX;
    for (int charIndex = 0; charIndex < text.length; charIndex++) {
      final char = text[charIndex];

      for (int row = 0; row < charHeight; row++) {
        for (int col = 0; col < charWidth; col++) {
          final isLit = BitmapFonts.isDotLit(char, row, col);
          final bulbX = charStartX + col * scaledTotalBulbSize;
          final bulbY = startY + row * scaledTotalBulbSize;
          final bulbCenter =
              Offset(bulbX + scaledBulbSize / 2, bulbY + scaledBulbSize / 2);
          final bulbRadius = scaledBulbSize / 2;

          // Calculate animation visibility
          final bulbVisible = _isBulbVisible(
              charIndex, col, row, text.length, charWidth, charHeight);

          // Determine color with optional warm tint
          Color bulbColor;
          if (gradientColors != null && gradientColors!.length >= 2) {
            final gradientPos =
                (charIndex * charWidth + col) / (textWidthBulbs - 1);
            bulbColor = _getGradientColor(gradientPos, gradientColors!);
          } else {
            bulbColor = primaryColor;
          }

          // Apply warm incandescent tint if enabled
          if (config.warmTint && isLit && bulbVisible) {
            bulbColor = _applyWarmTint(bulbColor);
          }

          // Draw socket first (behind bulb)
          if (config.showSocket) {
            _drawSocket(canvas, bulbCenter, bulbRadius, isLit);
          }

          if (isLit && bulbVisible) {
            // Draw glow effect if enabled (larger, softer glow)
            if (config.showGlow) {
              _drawGlow(canvas, bulbCenter, bulbRadius, bulbColor);
            }

            // Draw the lit bulb with enhanced 3D effect
            _drawLitBulb(canvas, bulbCenter, bulbRadius, bulbColor);
          } else {
            // Draw unlit bulb
            _drawUnlitBulb(canvas, bulbCenter, bulbRadius, bulbColor);
          }
        }
      }

      charStartX += (charWidth + charSpacing) * scaledTotalBulbSize;
    }
  }

  Color _applyWarmTint(Color color) {
    // Shift color towards warm incandescent (add orange/yellow)
    final hsl = HSLColor.fromColor(color);
    // Slightly shift hue towards warm and increase saturation
    final warmHue = (hsl.hue + 15) % 360; // Shift towards orange
    final warmSaturation = (hsl.saturation * 1.1).clamp(0.0, 1.0);
    final warmLightness = (hsl.lightness * 1.05).clamp(0.0, 1.0);
    return hsl
        .withHue(warmHue)
        .withSaturation(warmSaturation)
        .withLightness(warmLightness)
        .toColor();
  }

  void _drawSocket(Canvas canvas, Offset center, double radius, bool isLit) {
    final socketRadius = radius * 1.2;

    // Outer metallic ring
    final outerRingPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        radius: 1.0,
        colors: [
          Colors.grey.shade400,
          Colors.grey.shade600,
          Colors.grey.shade800,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: socketRadius));

    canvas.drawCircle(center, socketRadius, outerRingPaint);

    // Inner socket ring (darker)
    final innerRingPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.grey.shade900;
    canvas.drawCircle(center, radius * 1.05, innerRingPaint);

    // Socket base (where bulb sits)
    final basePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isLit ? Colors.grey.shade800 : Colors.grey.shade900;
    canvas.drawCircle(center, radius * 0.95, basePaint);
  }

  void _drawGlow(Canvas canvas, Offset center, double radius, Color color) {
    // Multiple layers of glow for soft, diffuse light
    final glowLayers = [
      (radius * 2.5, 0.15 * config.glowIntensity),
      (radius * 2.0, 0.25 * config.glowIntensity),
      (radius * 1.6, 0.35 * config.glowIntensity),
    ];

    for (final (glowRadius, alpha) in glowLayers) {
      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.4)
        ..color = color.withValues(alpha: alpha);
      canvas.drawCircle(center, glowRadius, glowPaint);
    }
  }

  void _drawLitBulb(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Glass bulb with strong 3D dome effect
    final gradient = RadialGradient(
      center: const Alignment(-0.4, -0.4),
      radius: 0.9,
      colors: [
        Color.lerp(color, Colors.white, 0.6)!, // Bright hotspot
        Color.lerp(color, Colors.white, 0.3)!,
        color,
        Color.lerp(color, Colors.black, 0.2)!,
      ],
      stops: const [0.0, 0.2, 0.6, 1.0],
    );

    paint.shader = gradient.createShader(
      Rect.fromCircle(center: center, radius: radius),
    );
    canvas.drawCircle(center, radius * 0.9, paint);

    // Bright highlight (specular reflection)
    final highlightPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
      radius * 0.2,
      highlightPaint,
    );

    // Secondary smaller highlight
    final highlight2Paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.15, center.dy - radius * 0.45),
      radius * 0.1,
      highlight2Paint,
    );

    // Subtle glass edge reflection
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.08
      ..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      -2.5,
      1.5,
      false,
      edgePaint,
    );
  }

  void _drawUnlitBulb(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Dark unlit bulb with subtle 3D
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.9,
      colors: [
        color.withValues(alpha: config.unlitOpacity * 2),
        color.withValues(alpha: config.unlitOpacity * 1.2),
        color.withValues(alpha: config.unlitOpacity * 0.5),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    paint.shader = gradient.createShader(
      Rect.fromCircle(center: center, radius: radius),
    );
    canvas.drawCircle(center, radius * 0.9, paint);

    // Very subtle glass reflection even when off
    final reflectPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.05);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.25, center.dy - radius * 0.25),
      radius * 0.15,
      reflectPaint,
    );
  }

  bool _isBulbVisible(int charIndex, int col, int row, int totalChars,
      int charWidth, int charHeight) {
    if (animationProgress >= 1.0 ||
        config.animation == StadiumAnimation.none) {
      return true;
    }

    final totalBulbs = totalChars * charWidth * charHeight;
    final bulbIndex = charIndex * charWidth * charHeight + row * charWidth + col;

    switch (config.animation) {
      case StadiumAnimation.chase:
        final threshold = (bulbIndex + 1) / totalBulbs;
        return animationProgress >= threshold;

      case StadiumAnimation.wave:
        final wavePos =
            math.sin((col / charWidth + animationProgress * 2) * math.pi);
        return wavePos > 0;

      case StadiumAnimation.sparkle:
        final random = math.sin(bulbIndex * 12.9898 + animationProgress * 100);
        return random > (1 - animationProgress * 2);

      case StadiumAnimation.none:
        return true;
    }
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
  bool shouldRepaint(StadiumBulbPainter oldDelegate) {
    return text != oldDelegate.text ||
        primaryColor != oldDelegate.primaryColor ||
        gradientColors != oldDelegate.gradientColors ||
        config != oldDelegate.config ||
        animationProgress != oldDelegate.animationProgress;
  }
}

/// Widget wrapper for Stadium Bulb with optional animation
class StadiumBulbText extends StatefulWidget {
  final String text;
  final Color primaryColor;
  final List<Color>? gradientColors;
  final StadiumBulbConfig config;
  final bool animate;

  const StadiumBulbText({
    super.key,
    required this.text,
    required this.primaryColor,
    this.gradientColors,
    this.config = const StadiumBulbConfig(),
    this.animate = false,
  });

  @override
  State<StadiumBulbText> createState() => _StadiumBulbTextState();
}

class _StadiumBulbTextState extends State<StadiumBulbText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _getAnimationDuration(),
    );

    if (widget.animate && widget.config.animation != StadiumAnimation.none) {
      if (widget.config.animation == StadiumAnimation.sparkle ||
          widget.config.animation == StadiumAnimation.wave) {
        _controller.repeat();
      } else {
        _controller.forward();
      }
    } else {
      _controller.value = 1.0;
    }
  }

  Duration _getAnimationDuration() {
    switch (widget.config.animation) {
      case StadiumAnimation.chase:
        return Duration(milliseconds: widget.text.length * 150);
      case StadiumAnimation.wave:
        return const Duration(milliseconds: 2000);
      case StadiumAnimation.sparkle:
        return const Duration(milliseconds: 1500);
      case StadiumAnimation.none:
        return Duration.zero;
    }
  }

  @override
  void didUpdateWidget(StadiumBulbText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text ||
        widget.config.animation != oldWidget.config.animation) {
      _controller.duration = _getAnimationDuration();
      if (widget.animate && widget.config.animation != StadiumAnimation.none) {
        if (widget.config.animation == StadiumAnimation.sparkle ||
            widget.config.animation == StadiumAnimation.wave) {
          _controller.repeat();
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
          painter: StadiumBulbPainter(
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
