import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/text_style_config.dart';
import 'text_style_renderer.dart';

/// Neon glow style text renderer.
/// Renders text with a glowing neon tube effect.
class NeonGlowRenderer extends TextStyleRenderer {
  final NeonGlowConfig config;

  NeonGlowRenderer({this.config = const NeonGlowConfig()});

  @override
  Widget build({
    required BuildContext context,
    required String text,
    required Color primaryColor,
    List<Color>? gradientColors,
    double fontSize = 48.0,
    double? animationProgress,
  }) {
    final glowColor = config.glowColor ?? primaryColor;
    final intensity = config.intensity.multiplier;

    return NeonGlowText(
      text: text,
      primaryColor: primaryColor,
      glowColor: glowColor,
      gradientColors: gradientColors,
      fontSize: fontSize,
      intensity: intensity,
      flickerMode: config.flickerMode,
      pulseGlow: config.pulseGlow,
    );
  }
}

/// Stateful widget for Neon Glow with animation support
class NeonGlowText extends StatefulWidget {
  final String text;
  final Color primaryColor;
  final Color glowColor;
  final List<Color>? gradientColors;
  final double fontSize;
  final double intensity;
  final NeonFlickerMode flickerMode;
  final bool pulseGlow;

  const NeonGlowText({
    super.key,
    required this.text,
    required this.primaryColor,
    required this.glowColor,
    this.gradientColors,
    this.fontSize = 48.0,
    this.intensity = 2.0,
    this.flickerMode = NeonFlickerMode.none,
    this.pulseGlow = false,
  });

  @override
  State<NeonGlowText> createState() => _NeonGlowTextState();
}

class _NeonGlowTextState extends State<NeonGlowText>
    with TickerProviderStateMixin {
  late AnimationController _flickerController;
  late AnimationController _pulseController;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Flicker animation controller
    _flickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    // Pulse glow animation controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _startAnimations();
  }

  void _startAnimations() {
    if (widget.flickerMode != NeonFlickerMode.none) {
      _runFlicker();
    }

    if (widget.pulseGlow) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _runFlicker() {
    if (!mounted) return;

    // Random delay between flickers
    final delay = Duration(
      milliseconds: widget.flickerMode == NeonFlickerMode.subtle
          ? _random.nextInt(3000) + 2000 // 2-5 seconds
          : _random.nextInt(1000) + 500, // 0.5-1.5 seconds
    );

    Future.delayed(delay, () {
      if (!mounted) return;

      // Quick flicker sequence
      _flickerController.forward().then((_) {
        if (!mounted) return;
        _flickerController.reverse().then((_) {
          if (!mounted) return;

          // Maybe do a second quick flicker
          if (_random.nextBool()) {
            Future.delayed(const Duration(milliseconds: 50), () {
              if (!mounted) return;
              _flickerController.forward().then((_) {
                if (!mounted) return;
                _flickerController.reverse().then((_) {
                  _runFlicker();
                });
              });
            });
          } else {
            _runFlicker();
          }
        });
      });
    });
  }

  @override
  void didUpdateWidget(NeonGlowText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.flickerMode != oldWidget.flickerMode) {
      if (widget.flickerMode == NeonFlickerMode.none) {
        _flickerController.stop();
        _flickerController.value = 0;
      } else {
        _runFlicker();
      }
    }

    if (widget.pulseGlow != oldWidget.pulseGlow) {
      if (widget.pulseGlow) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _flickerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flickerController, _pulseController]),
      builder: (context, child) {
        // Calculate flicker opacity reduction
        double flickerOpacity = 1.0;
        if (widget.flickerMode != NeonFlickerMode.none) {
          final flickerAmount = widget.flickerMode == NeonFlickerMode.subtle
              ? 0.3
              : 0.6;
          flickerOpacity = 1.0 - (_flickerController.value * flickerAmount);
        }

        // Calculate pulse intensity multiplier
        double pulseMultiplier = 1.0;
        if (widget.pulseGlow) {
          pulseMultiplier = 0.7 + (_pulseController.value * 0.6); // 0.7 - 1.3
        }

        return _buildNeonLayers(flickerOpacity, pulseMultiplier);
      },
    );
  }

  Widget _buildNeonLayers(double flickerOpacity, double pulseMultiplier) {
    final effectiveIntensity = widget.intensity * pulseMultiplier;

    // Base text style
    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      fontWeight: FontWeight.bold,
      letterSpacing: 2.0,
    );

    // Build the glow layers
    final layers = <Widget>[];

    // Outer glow layers (multiple for smoother falloff)
    final glowLevels = [
      (sigma: 25.0 * effectiveIntensity, opacity: 0.15),
      (sigma: 15.0 * effectiveIntensity, opacity: 0.25),
      (sigma: 8.0 * effectiveIntensity, opacity: 0.35),
      (sigma: 4.0 * effectiveIntensity, opacity: 0.5),
    ];

    for (final level in glowLevels) {
      layers.add(
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: level.sigma,
            sigmaY: level.sigma,
          ),
          child: _buildTextWidget(
            baseStyle.copyWith(
              color: widget.glowColor
                  .withValues(alpha: level.opacity * flickerOpacity),
            ),
          ),
        ),
      );
    }

    // Inner bright glow
    layers.add(
      ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: _buildTextWidget(
          baseStyle.copyWith(
            color: _getLightenedColor(widget.glowColor, 0.3)
                .withValues(alpha: 0.8 * flickerOpacity),
          ),
        ),
      ),
    );

    // Core white/bright center
    layers.add(
      _buildTextWidget(
        baseStyle.copyWith(
          color: _getLightenedColor(widget.primaryColor, 0.8)
              .withValues(alpha: flickerOpacity),
        ),
      ),
    );

    return Stack(
      alignment: Alignment.center,
      children: layers,
    );
  }

  Widget _buildTextWidget(TextStyle style) {
    final text = Text(
      widget.text,
      style: style,
      textAlign: TextAlign.center,
    );

    // Apply gradient if provided
    if (widget.gradientColors != null && widget.gradientColors!.length >= 2) {
      return ShaderMask(
        shaderCallback: (bounds) {
          return LinearGradient(
            colors: widget.gradientColors!,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds);
        },
        blendMode: BlendMode.srcIn,
        child: text,
      );
    }

    return text;
  }

  /// Lighten a color by mixing with white
  Color _getLightenedColor(Color color, double amount) {
    return Color.lerp(color, Colors.white, amount)!;
  }
}
