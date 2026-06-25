import 'package:flutter/material.dart';

/// Available text display styles for Concert Mode
enum TextDisplayStyle {
  normal,
  ledMatrix,
  neon,
  sevenSegment,
  pixel,
  stadium,
}

/// Extension to provide display names and icons for styles
extension TextDisplayStyleExtension on TextDisplayStyle {
  String get displayName {
    switch (this) {
      case TextDisplayStyle.normal:
        return 'Normal';
      case TextDisplayStyle.ledMatrix:
        return 'LED';
      case TextDisplayStyle.neon:
        return 'Neon';
      case TextDisplayStyle.sevenSegment:
        return '7-Segment';
      case TextDisplayStyle.pixel:
        return 'Pixel';
      case TextDisplayStyle.stadium:
        return 'Stadium';
    }
  }

  /// Whether this style is available (All phases implemented)
  bool get isAvailable {
    return true; // All styles now available
  }
}

// ============================================================================
// LED Matrix Configuration
// ============================================================================

enum LEDDotSize {
  small,
  medium,
  large,
}

extension LEDDotSizeExtension on LEDDotSize {
  double get pixels {
    switch (this) {
      case LEDDotSize.small:
        return 4.0;
      case LEDDotSize.medium:
        return 6.0;
      case LEDDotSize.large:
        return 8.0;
    }
  }

  String get displayName {
    switch (this) {
      case LEDDotSize.small:
        return 'Small';
      case LEDDotSize.medium:
        return 'Medium';
      case LEDDotSize.large:
        return 'Large';
    }
  }
}

enum LEDDotShape {
  circle,
  square,
  roundedSquare,
}

extension LEDDotShapeExtension on LEDDotShape {
  String get displayName {
    switch (this) {
      case LEDDotShape.circle:
        return 'Circle';
      case LEDDotShape.square:
        return 'Square';
      case LEDDotShape.roundedSquare:
        return 'Rounded';
    }
  }
}

enum LEDDotSpacing {
  tight,
  normal,
  loose,
}

extension LEDDotSpacingExtension on LEDDotSpacing {
  double get pixels {
    switch (this) {
      case LEDDotSpacing.tight:
        return 1.0;
      case LEDDotSpacing.normal:
        return 2.0;
      case LEDDotSpacing.loose:
        return 3.0;
    }
  }

  String get displayName {
    switch (this) {
      case LEDDotSpacing.tight:
        return 'Tight';
      case LEDDotSpacing.normal:
        return 'Normal';
      case LEDDotSpacing.loose:
        return 'Loose';
    }
  }
}

enum LEDAnimation {
  none,
  scan,
  randomFill,
  typewriter,
}

extension LEDAnimationExtension on LEDAnimation {
  String get displayName {
    switch (this) {
      case LEDAnimation.none:
        return 'None';
      case LEDAnimation.scan:
        return 'Scan';
      case LEDAnimation.randomFill:
        return 'Random Fill';
      case LEDAnimation.typewriter:
        return 'Typewriter';
    }
  }
}

class LEDMatrixConfig {
  final LEDDotSize dotSize;
  final LEDDotShape dotShape;
  final LEDDotSpacing dotSpacing;
  final double unlitOpacity;
  final LEDAnimation animation;
  final bool useEmojiColors; // Show emojis in their natural colors

  const LEDMatrixConfig({
    this.dotSize = LEDDotSize.medium,
    this.dotShape = LEDDotShape.circle,
    this.dotSpacing = LEDDotSpacing.normal,
    this.unlitOpacity = 0.15,
    this.animation = LEDAnimation.none,
    this.useEmojiColors = true,
  });

  LEDMatrixConfig copyWith({
    LEDDotSize? dotSize,
    LEDDotShape? dotShape,
    LEDDotSpacing? dotSpacing,
    double? unlitOpacity,
    LEDAnimation? animation,
    bool? useEmojiColors,
  }) {
    return LEDMatrixConfig(
      dotSize: dotSize ?? this.dotSize,
      dotShape: dotShape ?? this.dotShape,
      dotSpacing: dotSpacing ?? this.dotSpacing,
      unlitOpacity: unlitOpacity ?? this.unlitOpacity,
      animation: animation ?? this.animation,
      useEmojiColors: useEmojiColors ?? this.useEmojiColors,
    );
  }

  Map<String, dynamic> toJson() => {
        'dotSize': dotSize.index,
        'dotShape': dotShape.index,
        'dotSpacing': dotSpacing.index,
        'unlitOpacity': unlitOpacity,
        'animation': animation.index,
        'useEmojiColors': useEmojiColors,
      };

  factory LEDMatrixConfig.fromJson(Map<String, dynamic> json) {
    return LEDMatrixConfig(
      dotSize: LEDDotSize.values[json['dotSize'] ?? 1],
      dotShape: LEDDotShape.values[json['dotShape'] ?? 0],
      dotSpacing: LEDDotSpacing.values[json['dotSpacing'] ?? 1],
      unlitOpacity: (json['unlitOpacity'] ?? 0.15).toDouble(),
      animation: LEDAnimation.values[json['animation'] ?? 0],
      useEmojiColors: json['useEmojiColors'] ?? true,
    );
  }
}

// ============================================================================
// Neon Glow Configuration
// ============================================================================

enum NeonGlowIntensity {
  subtle,
  medium,
  intense,
}

extension NeonGlowIntensityExtension on NeonGlowIntensity {
  double get multiplier {
    switch (this) {
      case NeonGlowIntensity.subtle:
        return 1.0;
      case NeonGlowIntensity.medium:
        return 2.0;
      case NeonGlowIntensity.intense:
        return 3.0;
    }
  }

  String get displayName {
    switch (this) {
      case NeonGlowIntensity.subtle:
        return 'Subtle';
      case NeonGlowIntensity.medium:
        return 'Medium';
      case NeonGlowIntensity.intense:
        return 'Intense';
    }
  }
}

enum NeonFlickerMode {
  none,
  subtle,
  heavy,
}

extension NeonFlickerModeExtension on NeonFlickerMode {
  String get displayName {
    switch (this) {
      case NeonFlickerMode.none:
        return 'None';
      case NeonFlickerMode.subtle:
        return 'Subtle';
      case NeonFlickerMode.heavy:
        return 'Heavy';
    }
  }
}

class NeonGlowConfig {
  final NeonGlowIntensity intensity;
  final Color? glowColor; // null = same as text color
  final NeonFlickerMode flickerMode;
  final bool pulseGlow;

  const NeonGlowConfig({
    this.intensity = NeonGlowIntensity.medium,
    this.glowColor,
    this.flickerMode = NeonFlickerMode.none,
    this.pulseGlow = false,
  });

  NeonGlowConfig copyWith({
    NeonGlowIntensity? intensity,
    Color? glowColor,
    bool clearGlowColor = false,
    NeonFlickerMode? flickerMode,
    bool? pulseGlow,
  }) {
    return NeonGlowConfig(
      intensity: intensity ?? this.intensity,
      glowColor: clearGlowColor ? null : (glowColor ?? this.glowColor),
      flickerMode: flickerMode ?? this.flickerMode,
      pulseGlow: pulseGlow ?? this.pulseGlow,
    );
  }

  Map<String, dynamic> toJson() => {
        'intensity': intensity.index,
        'glowColor': glowColor?.toARGB32(),
        'flickerMode': flickerMode.index,
        'pulseGlow': pulseGlow,
      };

  factory NeonGlowConfig.fromJson(Map<String, dynamic> json) {
    return NeonGlowConfig(
      intensity: NeonGlowIntensity.values[json['intensity'] ?? 1],
      glowColor:
          json['glowColor'] != null ? Color(json['glowColor'] as int) : null,
      flickerMode: NeonFlickerMode.values[json['flickerMode'] ?? 0],
      pulseGlow: json['pulseGlow'] ?? false,
    );
  }
}

// ============================================================================
// Seven Segment Configuration
// ============================================================================

enum SegmentStyle {
  sharp,
  rounded,
}

extension SegmentStyleExtension on SegmentStyle {
  String get displayName {
    switch (this) {
      case SegmentStyle.sharp:
        return 'Sharp';
      case SegmentStyle.rounded:
        return 'Rounded';
    }
  }
}

enum SegmentThickness {
  thin,
  normal,
  thick,
}

extension SegmentThicknessExtension on SegmentThickness {
  double get multiplier {
    switch (this) {
      case SegmentThickness.thin:
        return 0.7;
      case SegmentThickness.normal:
        return 1.0;
      case SegmentThickness.thick:
        return 1.4;
    }
  }

  String get displayName {
    switch (this) {
      case SegmentThickness.thin:
        return 'Thin';
      case SegmentThickness.normal:
        return 'Normal';
      case SegmentThickness.thick:
        return 'Thick';
    }
  }
}

enum SevenSegmentAnimation {
  none,
  segmentWipe,
  countUp,
}

extension SevenSegmentAnimationExtension on SevenSegmentAnimation {
  String get displayName {
    switch (this) {
      case SevenSegmentAnimation.none:
        return 'None';
      case SevenSegmentAnimation.segmentWipe:
        return 'Segment Wipe';
      case SevenSegmentAnimation.countUp:
        return 'Count Up';
    }
  }
}

class SevenSegmentConfig {
  final SegmentStyle style;
  final SegmentThickness thickness;
  final double offSegmentOpacity;
  final SevenSegmentAnimation animation;

  const SevenSegmentConfig({
    this.style = SegmentStyle.rounded,
    this.thickness = SegmentThickness.normal,
    this.offSegmentOpacity = 0.1,
    this.animation = SevenSegmentAnimation.none,
  });

  SevenSegmentConfig copyWith({
    SegmentStyle? style,
    SegmentThickness? thickness,
    double? offSegmentOpacity,
    SevenSegmentAnimation? animation,
  }) {
    return SevenSegmentConfig(
      style: style ?? this.style,
      thickness: thickness ?? this.thickness,
      offSegmentOpacity: offSegmentOpacity ?? this.offSegmentOpacity,
      animation: animation ?? this.animation,
    );
  }

  Map<String, dynamic> toJson() => {
        'style': style.index,
        'thickness': thickness.index,
        'offSegmentOpacity': offSegmentOpacity,
        'animation': animation.index,
      };

  factory SevenSegmentConfig.fromJson(Map<String, dynamic> json) {
    return SevenSegmentConfig(
      style: SegmentStyle.values[json['style'] ?? 1],
      thickness: SegmentThickness.values[json['thickness'] ?? 1],
      offSegmentOpacity: (json['offSegmentOpacity'] ?? 0.1).toDouble(),
      animation: SevenSegmentAnimation.values[json['animation'] ?? 0],
    );
  }
}

// ============================================================================
// Pixel/Retro Configuration (Phase 3)
// ============================================================================

enum PixelSize {
  tiny,
  small,
  medium,
  large,
}

extension PixelSizeExtension on PixelSize {
  double get pixels {
    switch (this) {
      case PixelSize.tiny:
        return 2.0;
      case PixelSize.small:
        return 3.0;
      case PixelSize.medium:
        return 4.0;
      case PixelSize.large:
        return 6.0;
    }
  }

  String get displayName {
    switch (this) {
      case PixelSize.tiny:
        return 'Tiny';
      case PixelSize.small:
        return 'Small';
      case PixelSize.medium:
        return 'Medium';
      case PixelSize.large:
        return 'Large';
    }
  }
}

enum PixelAnimation {
  none,
  crtFlicker,
  glitch,
}

extension PixelAnimationExtension on PixelAnimation {
  String get displayName {
    switch (this) {
      case PixelAnimation.none:
        return 'None';
      case PixelAnimation.crtFlicker:
        return 'CRT Flicker';
      case PixelAnimation.glitch:
        return 'Glitch';
    }
  }
}

class PixelRetroConfig {
  final PixelSize pixelSize;
  final bool showScanlines;
  final double scanlineOpacity;
  final bool showCrtCurve;
  final PixelAnimation animation;
  final bool chromaShift;

  const PixelRetroConfig({
    this.pixelSize = PixelSize.medium,
    this.showScanlines = true,
    this.scanlineOpacity = 0.3,
    this.showCrtCurve = false,
    this.animation = PixelAnimation.none,
    this.chromaShift = false,
  });

  PixelRetroConfig copyWith({
    PixelSize? pixelSize,
    bool? showScanlines,
    double? scanlineOpacity,
    bool? showCrtCurve,
    PixelAnimation? animation,
    bool? chromaShift,
  }) {
    return PixelRetroConfig(
      pixelSize: pixelSize ?? this.pixelSize,
      showScanlines: showScanlines ?? this.showScanlines,
      scanlineOpacity: scanlineOpacity ?? this.scanlineOpacity,
      showCrtCurve: showCrtCurve ?? this.showCrtCurve,
      animation: animation ?? this.animation,
      chromaShift: chromaShift ?? this.chromaShift,
    );
  }

  Map<String, dynamic> toJson() => {
        'pixelSize': pixelSize.index,
        'showScanlines': showScanlines,
        'scanlineOpacity': scanlineOpacity,
        'showCrtCurve': showCrtCurve,
        'animation': animation.index,
        'chromaShift': chromaShift,
      };

  factory PixelRetroConfig.fromJson(Map<String, dynamic> json) {
    return PixelRetroConfig(
      pixelSize: PixelSize.values[json['pixelSize'] ?? 2],
      showScanlines: json['showScanlines'] ?? true,
      scanlineOpacity: (json['scanlineOpacity'] ?? 0.3).toDouble(),
      showCrtCurve: json['showCrtCurve'] ?? false,
      animation: PixelAnimation.values[json['animation'] ?? 0],
      chromaShift: json['chromaShift'] ?? false,
    );
  }
}

// ============================================================================
// Stadium Bulb Configuration (Phase 3)
// ============================================================================

enum BulbSize {
  small,
  medium,
  large,
  extraLarge,
}

extension BulbSizeExtension on BulbSize {
  double get pixels {
    switch (this) {
      case BulbSize.small:
        return 16.0;  // Much larger than LED (was 8)
      case BulbSize.medium:
        return 24.0;  // (was 12)
      case BulbSize.large:
        return 32.0;  // (was 16)
      case BulbSize.extraLarge:
        return 40.0;  // (was 20)
    }
  }

  String get displayName {
    switch (this) {
      case BulbSize.small:
        return 'Small';
      case BulbSize.medium:
        return 'Medium';
      case BulbSize.large:
        return 'Large';
      case BulbSize.extraLarge:
        return 'X-Large';
    }
  }
}

enum BulbSpacing {
  tight,
  normal,
  wide,
}

extension BulbSpacingExtension on BulbSpacing {
  double get pixels {
    switch (this) {
      case BulbSpacing.tight:
        return 2.0;
      case BulbSpacing.normal:
        return 4.0;
      case BulbSpacing.wide:
        return 6.0;
    }
  }

  String get displayName {
    switch (this) {
      case BulbSpacing.tight:
        return 'Tight';
      case BulbSpacing.normal:
        return 'Normal';
      case BulbSpacing.wide:
        return 'Wide';
    }
  }
}

enum StadiumAnimation {
  none,
  chase,
  wave,
  sparkle,
}

extension StadiumAnimationExtension on StadiumAnimation {
  String get displayName {
    switch (this) {
      case StadiumAnimation.none:
        return 'None';
      case StadiumAnimation.chase:
        return 'Chase';
      case StadiumAnimation.wave:
        return 'Wave';
      case StadiumAnimation.sparkle:
        return 'Sparkle';
    }
  }
}

class StadiumBulbConfig {
  final BulbSize bulbSize;
  final BulbSpacing bulbSpacing;
  final double unlitOpacity;
  final bool showGlow;
  final double glowIntensity;
  final bool showSocket;  // Show metallic socket around bulbs
  final bool warmTint;    // Add warm incandescent tint
  final StadiumAnimation animation;

  const StadiumBulbConfig({
    this.bulbSize = BulbSize.medium,
    this.bulbSpacing = BulbSpacing.normal,
    this.unlitOpacity = 0.1,
    this.showGlow = true,
    this.glowIntensity = 0.8,  // Higher default glow
    this.showSocket = true,    // Show sockets by default
    this.warmTint = true,      // Warm incandescent look
    this.animation = StadiumAnimation.none,
  });

  StadiumBulbConfig copyWith({
    BulbSize? bulbSize,
    BulbSpacing? bulbSpacing,
    double? unlitOpacity,
    bool? showGlow,
    double? glowIntensity,
    bool? showSocket,
    bool? warmTint,
    StadiumAnimation? animation,
  }) {
    return StadiumBulbConfig(
      bulbSize: bulbSize ?? this.bulbSize,
      bulbSpacing: bulbSpacing ?? this.bulbSpacing,
      unlitOpacity: unlitOpacity ?? this.unlitOpacity,
      showGlow: showGlow ?? this.showGlow,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      showSocket: showSocket ?? this.showSocket,
      warmTint: warmTint ?? this.warmTint,
      animation: animation ?? this.animation,
    );
  }

  Map<String, dynamic> toJson() => {
        'bulbSize': bulbSize.index,
        'bulbSpacing': bulbSpacing.index,
        'unlitOpacity': unlitOpacity,
        'showGlow': showGlow,
        'glowIntensity': glowIntensity,
        'showSocket': showSocket,
        'warmTint': warmTint,
        'animation': animation.index,
      };

  factory StadiumBulbConfig.fromJson(Map<String, dynamic> json) {
    return StadiumBulbConfig(
      bulbSize: BulbSize.values[json['bulbSize'] ?? 1],
      bulbSpacing: BulbSpacing.values[json['bulbSpacing'] ?? 1],
      unlitOpacity: (json['unlitOpacity'] ?? 0.1).toDouble(),
      showGlow: json['showGlow'] ?? true,
      glowIntensity: (json['glowIntensity'] ?? 0.8).toDouble(),
      showSocket: json['showSocket'] ?? true,
      warmTint: json['warmTint'] ?? true,
      animation: StadiumAnimation.values[json['animation'] ?? 0],
    );
  }
}

// ============================================================================
// Combined Text Style Configuration
// ============================================================================

class TextStyleConfig {
  final TextDisplayStyle style;
  final LEDMatrixConfig ledConfig;
  final NeonGlowConfig neonConfig;
  final SevenSegmentConfig sevenSegmentConfig;
  final PixelRetroConfig pixelConfig;
  final StadiumBulbConfig stadiumConfig;

  const TextStyleConfig({
    this.style = TextDisplayStyle.normal,
    this.ledConfig = const LEDMatrixConfig(),
    this.neonConfig = const NeonGlowConfig(),
    this.sevenSegmentConfig = const SevenSegmentConfig(),
    this.pixelConfig = const PixelRetroConfig(),
    this.stadiumConfig = const StadiumBulbConfig(),
  });

  TextStyleConfig copyWith({
    TextDisplayStyle? style,
    LEDMatrixConfig? ledConfig,
    NeonGlowConfig? neonConfig,
    SevenSegmentConfig? sevenSegmentConfig,
    PixelRetroConfig? pixelConfig,
    StadiumBulbConfig? stadiumConfig,
  }) {
    return TextStyleConfig(
      style: style ?? this.style,
      ledConfig: ledConfig ?? this.ledConfig,
      neonConfig: neonConfig ?? this.neonConfig,
      sevenSegmentConfig: sevenSegmentConfig ?? this.sevenSegmentConfig,
      pixelConfig: pixelConfig ?? this.pixelConfig,
      stadiumConfig: stadiumConfig ?? this.stadiumConfig,
    );
  }

  Map<String, dynamic> toJson() => {
        'style': style.index,
        'ledConfig': ledConfig.toJson(),
        'neonConfig': neonConfig.toJson(),
        'sevenSegmentConfig': sevenSegmentConfig.toJson(),
        'pixelConfig': pixelConfig.toJson(),
        'stadiumConfig': stadiumConfig.toJson(),
      };

  factory TextStyleConfig.fromJson(Map<String, dynamic> json) {
    return TextStyleConfig(
      style: TextDisplayStyle.values[json['style'] ?? 0],
      ledConfig: json['ledConfig'] != null
          ? LEDMatrixConfig.fromJson(json['ledConfig'])
          : const LEDMatrixConfig(),
      neonConfig: json['neonConfig'] != null
          ? NeonGlowConfig.fromJson(json['neonConfig'])
          : const NeonGlowConfig(),
      sevenSegmentConfig: json['sevenSegmentConfig'] != null
          ? SevenSegmentConfig.fromJson(json['sevenSegmentConfig'])
          : const SevenSegmentConfig(),
      pixelConfig: json['pixelConfig'] != null
          ? PixelRetroConfig.fromJson(json['pixelConfig'])
          : const PixelRetroConfig(),
      stadiumConfig: json['stadiumConfig'] != null
          ? StadiumBulbConfig.fromJson(json['stadiumConfig'])
          : const StadiumBulbConfig(),
    );
  }
}
