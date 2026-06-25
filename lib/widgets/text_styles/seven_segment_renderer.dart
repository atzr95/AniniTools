import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/text_style_config.dart';

/// Seven-Segment display style text renderer.
/// Renders text as classic LCD/LED segment displays.
class SevenSegmentRenderer {
  final SevenSegmentConfig config;

  SevenSegmentRenderer({this.config = const SevenSegmentConfig()});

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
          painter: SevenSegmentPainter(
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

/// Seven-segment character mapping
/// Segments are labeled:
///    AAA
///   F   B
///   F   B
///    GGG
///   E   C
///   E   C
///    DDD
///
/// Each character maps to which segments are ON (bits: 0=A, 1=B, 2=C, 3=D, 4=E, 5=F, 6=G)
class SevenSegmentData {
  // Standard segment patterns (bit order: GFEDCBA)
  static const Map<String, int> patterns = {
    '0': 0x3F, // 0111111 - ABCDEF
    '1': 0x06, // 0000110 - BC
    '2': 0x5B, // 1011011 - ABDEG
    '3': 0x4F, // 1001111 - ABCDG
    '4': 0x66, // 1100110 - BCFG
    '5': 0x6D, // 1101101 - ACDFG
    '6': 0x7D, // 1111101 - ACDEFG
    '7': 0x07, // 0000111 - ABC
    '8': 0x7F, // 1111111 - ABCDEFG
    '9': 0x6F, // 1101111 - ABCDFG
    'A': 0x77, // 1110111 - ABCEFG
    'B': 0x7C, // 1111100 - CDEFG (lowercase b)
    'C': 0x39, // 0111001 - ADEF
    'D': 0x5E, // 1011110 - BCDEG (lowercase d)
    'E': 0x79, // 1111001 - ADEFG
    'F': 0x71, // 1110001 - AEFG
    'G': 0x3D, // 0111101 - ACDEF
    'H': 0x76, // 1110110 - BCEFG
    'I': 0x06, // 0000110 - BC (same as 1)
    'J': 0x1E, // 0011110 - BCDE
    'K': 0x76, // 1110110 - BCEFG (approximation, same as H)
    'L': 0x38, // 0111000 - DEF
    'M': 0x37, // 0110111 - ABCEF (approximation)
    'N': 0x54, // 1010100 - CEG (lowercase n)
    'O': 0x3F, // 0111111 - ABCDEF (same as 0)
    'P': 0x73, // 1110011 - ABEFG
    'Q': 0x67, // 1100111 - ABCFG
    'R': 0x50, // 1010000 - EG (lowercase r)
    'S': 0x6D, // 1101101 - ACDFG (same as 5)
    'T': 0x78, // 1111000 - DEFG
    'U': 0x3E, // 0111110 - BCDEF
    'V': 0x3E, // 0111110 - BCDEF (same as U)
    'W': 0x3E, // 0111110 - BCDEF (approximation)
    'X': 0x76, // 1110110 - BCEFG (approximation)
    'Y': 0x6E, // 1101110 - BCDFG
    'Z': 0x5B, // 1011011 - ABDEG (same as 2)
    ' ': 0x00, // All off
    '-': 0x40, // 1000000 - G only
    '_': 0x08, // 0001000 - D only
    '.': 0x80, // Special: decimal point (handled separately)
    ':': 0x00, // Special: colon (handled separately)
  };

  static int getPattern(String char) {
    final upper = char.toUpperCase();
    return patterns[upper] ?? 0x00;
  }

  static bool isSegmentOn(int pattern, int segmentIndex) {
    return (pattern & (1 << segmentIndex)) != 0;
  }
}

/// CustomPainter that renders text as seven-segment displays.
class SevenSegmentPainter extends CustomPainter {
  final String text;
  final Color primaryColor;
  final List<Color>? gradientColors;
  final SevenSegmentConfig config;
  final double animationProgress;

  // Segment dimensions relative to character height
  static const double segmentLengthRatio = 0.35;
  static const double segmentWidthRatio = 0.12;
  static const double charAspectRatio = 0.6; // width/height

  SevenSegmentPainter({
    required this.text,
    required this.primaryColor,
    this.gradientColors,
    required this.config,
    this.animationProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    // Calculate character dimensions
    final availableWidth = size.width * 0.95;
    final availableHeight = size.height * 0.8;

    // Calculate character size to fit all text
    final charWidth = availableWidth / text.length;
    final charHeight = charWidth / charAspectRatio;

    // Scale down if too tall
    final finalCharHeight = math.min(charHeight, availableHeight);
    final finalCharWidth = finalCharHeight * charAspectRatio;

    // Calculate starting position (centered)
    final totalWidth = finalCharWidth * text.length;
    final startX = (size.width - totalWidth) / 2;
    final startY = (size.height - finalCharHeight) / 2;

    // Segment dimensions
    final segmentLength = finalCharHeight * segmentLengthRatio;
    final segmentWidth =
        finalCharHeight * segmentWidthRatio * config.thickness.multiplier;

    // Draw each character
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final charX = startX + i * finalCharWidth;
      final charY = startY;

      // Determine color
      Color charColor;
      if (gradientColors != null && gradientColors!.length >= 2) {
        final gradientPos = i / (text.length - 1).clamp(1, text.length);
        charColor = _getGradientColor(gradientPos, gradientColors!);
      } else {
        charColor = primaryColor;
      }

      // Get segment pattern
      final pattern = SevenSegmentData.getPattern(char);

      // Check animation visibility
      final isVisible = _isCharVisible(i, text.length);

      // Draw all 7 segments
      _drawCharacter(
        canvas,
        charX,
        charY,
        finalCharWidth,
        finalCharHeight,
        segmentLength,
        segmentWidth,
        pattern,
        charColor,
        isVisible,
      );

      // Handle special characters
      if (char == '.' || char == ':') {
        _drawSpecialChar(
          canvas,
          char,
          charX,
          charY,
          finalCharWidth,
          finalCharHeight,
          segmentWidth,
          charColor,
          isVisible,
        );
      }
    }
  }

  void _drawCharacter(
    Canvas canvas,
    double x,
    double y,
    double charWidth,
    double charHeight,
    double segLength,
    double segWidth,
    int pattern,
    Color color,
    bool isVisible,
  ) {
    // Calculate segment positions
    final horizontalPadding = (charWidth - segLength) / 2;
    final verticalSegLength = (charHeight - segWidth * 3) / 2;

    // Segment A (top horizontal)
    _drawSegment(
      canvas,
      x + horizontalPadding,
      y,
      segLength,
      segWidth,
      true, // horizontal
      SevenSegmentData.isSegmentOn(pattern, 0) && isVisible,
      color,
    );

    // Segment B (top-right vertical)
    _drawSegment(
      canvas,
      x + horizontalPadding + segLength - segWidth,
      y + segWidth,
      verticalSegLength,
      segWidth,
      false, // vertical
      SevenSegmentData.isSegmentOn(pattern, 1) && isVisible,
      color,
    );

    // Segment C (bottom-right vertical)
    _drawSegment(
      canvas,
      x + horizontalPadding + segLength - segWidth,
      y + segWidth * 2 + verticalSegLength,
      verticalSegLength,
      segWidth,
      false, // vertical
      SevenSegmentData.isSegmentOn(pattern, 2) && isVisible,
      color,
    );

    // Segment D (bottom horizontal)
    _drawSegment(
      canvas,
      x + horizontalPadding,
      y + charHeight - segWidth,
      segLength,
      segWidth,
      true, // horizontal
      SevenSegmentData.isSegmentOn(pattern, 3) && isVisible,
      color,
    );

    // Segment E (bottom-left vertical)
    _drawSegment(
      canvas,
      x + horizontalPadding,
      y + segWidth * 2 + verticalSegLength,
      verticalSegLength,
      segWidth,
      false, // vertical
      SevenSegmentData.isSegmentOn(pattern, 4) && isVisible,
      color,
    );

    // Segment F (top-left vertical)
    _drawSegment(
      canvas,
      x + horizontalPadding,
      y + segWidth,
      verticalSegLength,
      segWidth,
      false, // vertical
      SevenSegmentData.isSegmentOn(pattern, 5) && isVisible,
      color,
    );

    // Segment G (middle horizontal)
    _drawSegment(
      canvas,
      x + horizontalPadding,
      y + segWidth + verticalSegLength,
      segLength,
      segWidth,
      true, // horizontal
      SevenSegmentData.isSegmentOn(pattern, 6) && isVisible,
      color,
    );
  }

  void _drawSegment(
    Canvas canvas,
    double x,
    double y,
    double length,
    double width,
    bool horizontal,
    bool isOn,
    Color color,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = isOn ? color : color.withValues(alpha: config.offSegmentOpacity);

    final path = Path();

    if (config.style == SegmentStyle.rounded) {
      // Rounded segment with pointed ends
      if (horizontal) {
        final halfWidth = width / 2;
        path.moveTo(x + halfWidth, y + halfWidth);
        path.lineTo(x + length - halfWidth, y + halfWidth);
        path.arcToPoint(
          Offset(x + length - halfWidth, y + halfWidth),
          radius: Radius.circular(halfWidth),
        );
        path.lineTo(x + length, y + halfWidth);
        path.lineTo(x + length - halfWidth, y);
        path.lineTo(x + halfWidth, y);
        path.lineTo(x, y + halfWidth);
        path.lineTo(x + halfWidth, y + width);
        path.lineTo(x + length - halfWidth, y + width);
        path.lineTo(x + length, y + halfWidth);
        path.close();
      } else {
        final halfWidth = width / 2;
        path.moveTo(x + halfWidth, y);
        path.lineTo(x + width, y + halfWidth);
        path.lineTo(x + width, y + length - halfWidth);
        path.lineTo(x + halfWidth, y + length);
        path.lineTo(x, y + length - halfWidth);
        path.lineTo(x, y + halfWidth);
        path.close();
      }
    } else {
      // Sharp rectangular segments
      if (horizontal) {
        canvas.drawRect(Rect.fromLTWH(x, y, length, width), paint);
        return;
      } else {
        canvas.drawRect(Rect.fromLTWH(x, y, width, length), paint);
        return;
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawSpecialChar(
    Canvas canvas,
    String char,
    double x,
    double y,
    double charWidth,
    double charHeight,
    double dotSize,
    Color color,
    bool isVisible,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = isVisible ? color : color.withValues(alpha: config.offSegmentOpacity);

    if (char == '.') {
      // Draw decimal point at bottom-right
      canvas.drawCircle(
        Offset(x + charWidth - dotSize, y + charHeight - dotSize),
        dotSize / 2,
        paint,
      );
    } else if (char == ':') {
      // Draw colon (two dots)
      final centerX = x + charWidth / 2;
      canvas.drawCircle(
        Offset(centerX, y + charHeight * 0.3),
        dotSize / 2,
        paint,
      );
      canvas.drawCircle(
        Offset(centerX, y + charHeight * 0.7),
        dotSize / 2,
        paint,
      );
    }
  }

  bool _isCharVisible(int charIndex, int totalChars) {
    if (animationProgress >= 1.0 ||
        config.animation == SevenSegmentAnimation.none) {
      return true;
    }

    if (config.animation == SevenSegmentAnimation.segmentWipe) {
      final threshold = (charIndex + 1) / totalChars;
      return animationProgress >= threshold;
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
  bool shouldRepaint(SevenSegmentPainter oldDelegate) {
    return text != oldDelegate.text ||
        primaryColor != oldDelegate.primaryColor ||
        gradientColors != oldDelegate.gradientColors ||
        config != oldDelegate.config ||
        animationProgress != oldDelegate.animationProgress;
  }
}

/// Widget wrapper for Seven-Segment with optional animation
class SevenSegmentText extends StatefulWidget {
  final String text;
  final Color primaryColor;
  final List<Color>? gradientColors;
  final SevenSegmentConfig config;
  final bool animate;

  const SevenSegmentText({
    super.key,
    required this.text,
    required this.primaryColor,
    this.gradientColors,
    this.config = const SevenSegmentConfig(),
    this.animate = false,
  });

  @override
  State<SevenSegmentText> createState() => _SevenSegmentTextState();
}

class _SevenSegmentTextState extends State<SevenSegmentText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _getAnimationDuration(),
    );

    if (widget.animate &&
        widget.config.animation != SevenSegmentAnimation.none) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  Duration _getAnimationDuration() {
    switch (widget.config.animation) {
      case SevenSegmentAnimation.segmentWipe:
        return Duration(milliseconds: widget.text.length * 100);
      case SevenSegmentAnimation.countUp:
        return const Duration(milliseconds: 1500);
      case SevenSegmentAnimation.none:
        return Duration.zero;
    }
  }

  @override
  void didUpdateWidget(SevenSegmentText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.text != oldWidget.text ||
        widget.config.animation != oldWidget.config.animation) {
      _controller.duration = _getAnimationDuration();
      if (widget.animate &&
          widget.config.animation != SevenSegmentAnimation.none) {
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
          painter: SevenSegmentPainter(
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
