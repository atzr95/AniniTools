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

class LEDMatrixConfig {
  final LEDDotSize dotSize;
  final LEDDotShape dotShape;
  final double unlitOpacity;
  final bool useEmojiColors; // Show emojis in their natural colors

  const LEDMatrixConfig({
    this.dotSize = LEDDotSize.medium,
    this.dotShape = LEDDotShape.circle,
    this.unlitOpacity = 0.15,
    this.useEmojiColors = true,
  });

  LEDMatrixConfig copyWith({
    LEDDotSize? dotSize,
    LEDDotShape? dotShape,
    double? unlitOpacity,
    bool? useEmojiColors,
  }) {
    return LEDMatrixConfig(
      dotSize: dotSize ?? this.dotSize,
      dotShape: dotShape ?? this.dotShape,
      unlitOpacity: unlitOpacity ?? this.unlitOpacity,
      useEmojiColors: useEmojiColors ?? this.useEmojiColors,
    );
  }

  Map<String, dynamic> toJson() => {
        'dotSize': dotSize.index,
        'dotShape': dotShape.index,
        'unlitOpacity': unlitOpacity,
        'useEmojiColors': useEmojiColors,
      };

  factory LEDMatrixConfig.fromJson(Map<String, dynamic> json) {
    return LEDMatrixConfig(
      dotSize: LEDDotSize.values[json['dotSize'] ?? 1],
      dotShape: LEDDotShape.values[json['dotShape'] ?? 0],
      unlitOpacity: (json['unlitOpacity'] ?? 0.15).toDouble(),
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

class SevenSegmentConfig {
  final SegmentStyle style;
  final SegmentThickness thickness;
  final double offSegmentOpacity;

  const SevenSegmentConfig({
    this.style = SegmentStyle.rounded,
    this.thickness = SegmentThickness.normal,
    this.offSegmentOpacity = 0.1,
  });

  SevenSegmentConfig copyWith({
    SegmentStyle? style,
    SegmentThickness? thickness,
    double? offSegmentOpacity,
  }) {
    return SevenSegmentConfig(
      style: style ?? this.style,
      thickness: thickness ?? this.thickness,
      offSegmentOpacity: offSegmentOpacity ?? this.offSegmentOpacity,
    );
  }

  Map<String, dynamic> toJson() => {
        'style': style.index,
        'thickness': thickness.index,
        'offSegmentOpacity': offSegmentOpacity,
      };

  factory SevenSegmentConfig.fromJson(Map<String, dynamic> json) {
    return SevenSegmentConfig(
      style: SegmentStyle.values[json['style'] ?? 1],
      thickness: SegmentThickness.values[json['thickness'] ?? 1],
      offSegmentOpacity: (json['offSegmentOpacity'] ?? 0.1).toDouble(),
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

class PixelRetroConfig {
  final PixelSize pixelSize;
  final bool showScanlines;
  final double scanlineOpacity;
  final bool showCrtCurve;
  final bool chromaShift;

  const PixelRetroConfig({
    this.pixelSize = PixelSize.medium,
    this.showScanlines = true,
    this.scanlineOpacity = 0.3,
    this.showCrtCurve = false,
    this.chromaShift = false,
  });

  PixelRetroConfig copyWith({
    PixelSize? pixelSize,
    bool? showScanlines,
    double? scanlineOpacity,
    bool? showCrtCurve,
    bool? chromaShift,
  }) {
    return PixelRetroConfig(
      pixelSize: pixelSize ?? this.pixelSize,
      showScanlines: showScanlines ?? this.showScanlines,
      scanlineOpacity: scanlineOpacity ?? this.scanlineOpacity,
      showCrtCurve: showCrtCurve ?? this.showCrtCurve,
      chromaShift: chromaShift ?? this.chromaShift,
    );
  }

  Map<String, dynamic> toJson() => {
        'pixelSize': pixelSize.index,
        'showScanlines': showScanlines,
        'scanlineOpacity': scanlineOpacity,
        'showCrtCurve': showCrtCurve,
        'chromaShift': chromaShift,
      };

  factory PixelRetroConfig.fromJson(Map<String, dynamic> json) {
    return PixelRetroConfig(
      pixelSize: PixelSize.values[json['pixelSize'] ?? 2],
      showScanlines: json['showScanlines'] ?? true,
      scanlineOpacity: (json['scanlineOpacity'] ?? 0.3).toDouble(),
      showCrtCurve: json['showCrtCurve'] ?? false,
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

class StadiumBulbConfig {
  final BulbSize bulbSize;
  final BulbSpacing bulbSpacing;
  final double unlitOpacity;
  final bool showGlow;
  final double glowIntensity;
  final bool showSocket;  // Show metallic socket around bulbs
  final bool warmTint;    // Add warm incandescent tint

  const StadiumBulbConfig({
    this.bulbSize = BulbSize.medium,
    this.bulbSpacing = BulbSpacing.normal,
    this.unlitOpacity = 0.1,
    this.showGlow = true,
    this.glowIntensity = 0.8,  // Higher default glow
    this.showSocket = true,    // Show sockets by default
    this.warmTint = true,      // Warm incandescent look
  });

  StadiumBulbConfig copyWith({
    BulbSize? bulbSize,
    BulbSpacing? bulbSpacing,
    double? unlitOpacity,
    bool? showGlow,
    double? glowIntensity,
    bool? showSocket,
    bool? warmTint,
  }) {
    return StadiumBulbConfig(
      bulbSize: bulbSize ?? this.bulbSize,
      bulbSpacing: bulbSpacing ?? this.bulbSpacing,
      unlitOpacity: unlitOpacity ?? this.unlitOpacity,
      showGlow: showGlow ?? this.showGlow,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      showSocket: showSocket ?? this.showSocket,
      warmTint: warmTint ?? this.warmTint,
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
    );
  }
}
