import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../viewmodels/sensor_viewmodel.dart';
import '../../widgets/measurement_card.dart';

/// Metal Detector Tool - Detect metal objects using magnetometer
class MetalDetectorScreen extends StatefulWidget {
  const MetalDetectorScreen({super.key});

  @override
  State<MetalDetectorScreen> createState() => _MetalDetectorScreenState();
}

class _MetalDetectorScreenState extends State<MetalDetectorScreen> {
  double _baselineMagnitude = 0.0;
  bool _isCalibrated = false;
  double _sensitivity = 50.0; // 0-100 scale
  bool _audioEnabled = true;

  double _maxRecorded = 0.0;
  final List<double> _history = [];
  static const int _maxHistoryLength = 100;

  Timer? _beepTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  double _lastDetectionStrength = -1; // Track last strength to avoid recreating timer

  // Smoothing for magnetic field to reduce false positives from hand movement
  double _smoothedMagnitude = 0.0;
  static const double _smoothingFactor = 0.15; // Stronger smoothing for stability
  final List<double> _calibrationSamples = [];

  // Dynamic baseline adjustment to prevent getting stuck at high values
  int _lowDetectionCount = 0;

  // Detection threshold - minimum deviation to consider (in µT)
  // Earth's field is ~25-65µT, natural variations are ~1-3µT
  static const double _minDetectionThreshold = 3.0; // Only detect changes > 3µT

  @override
  void initState() {
    super.initState();
    // Set audio player to low latency mode for quick beeps
    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    // Auto-calibrate on start after collecting samples
    _startAutoCalibration();
  }

  void _startAutoCalibration() async {
    // Collect multiple samples for better baseline (20 samples over 2 seconds)
    _calibrationSamples.clear();

    for (int i = 0; i < 20; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        final viewModel = Provider.of<SensorViewModel>(context, listen: false);
        _calibrationSamples.add(viewModel.magneticField);
      }
    }

    if (mounted && _calibrationSamples.isNotEmpty) {
      // Use median of samples as baseline (more robust against outliers)
      _calibrationSamples.sort();
      final median = _calibrationSamples[_calibrationSamples.length ~/ 2];
      _calibrate(median);
    }
  }

  void _calibrate(double currentMagnitude) {
    setState(() {
      _baselineMagnitude = currentMagnitude;
      _smoothedMagnitude = currentMagnitude;
      _isCalibrated = true;
      _maxRecorded = 0.0;
      _history.clear();
      _calibrationSamples.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calibrated to current environment')),
    );
  }

  void _resetCalibration() {
    setState(() {
      _isCalibrated = false;
      _baselineMagnitude = 0.0;
      _smoothedMagnitude = 0.0;
      _maxRecorded = 0.0;
      _history.clear();
      _calibrationSamples.clear();
      _lowDetectionCount = 0;
    });
  }

  void _updateHistory(double value) {
    setState(() {
      _history.add(value);
      if (_history.length > _maxHistoryLength) {
        _history.removeAt(0);
      }
      if (value > _maxRecorded) {
        _maxRecorded = value;
      }
    });
  }

  void _playBeep() async {
    try {
      // Heavy haptic feedback creates a strong "beep" feeling
      HapticFeedback.heavyImpact();

      // Play audible beep sound from asset
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'), volume: 0.5);
    } catch (e) {
      debugPrint('Beep error: $e');
    }
  }

  void _updateBeepFrequency(double detectionStrength) {
    if (!_audioEnabled || !_isCalibrated) {
      _beepTimer?.cancel();
      _lastDetectionStrength = -1;
      return;
    }

    // Only update if strength changed significantly (by more than 2%)
    // This prevents constant timer recreation
    if ((detectionStrength - _lastDetectionStrength).abs() < 2.0) {
      return; // Skip update if change is too small
    }

    _lastDetectionStrength = detectionStrength;

    // Cancel existing timer
    _beepTimer?.cancel();

    // Determine beep interval based on detection strength
    // Higher strength = faster beeps (like a real metal detector)
    if (detectionStrength > 1) {
      // Map detection strength to beep interval
      // 1-100 strength -> 1200ms to 80ms interval
      // Low detection: very slow beeps (1.2 seconds)
      // Medium detection: moderate beeps (500ms)
      // High detection: rapid beeps (80ms = 12 per second)
      final interval = math.max(80, 1200 - (detectionStrength * 11.2)).toInt();

      _beepTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
        if (mounted && _audioEnabled && _isCalibrated) {
          _playBeep();
        }
      });
    } else {
      // Stop beeping when detection is very low
      _beepTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _beepTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metal Detector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Calibrate',
            onPressed: () => _startAutoCalibration(),
          ),
          if (_isCalibrated)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset',
              onPressed: _resetCalibration,
            ),
        ],
      ),
      body: Consumer<SensorViewModel>(
        builder: (context, viewModel, _) {
          // Get magnetic field magnitude from viewModel
          final magnitude = viewModel.magneticField;

          // Apply exponential smoothing to reduce noise from hand movement
          if (_isCalibrated) {
            _smoothedMagnitude = _smoothedMagnitude * (1 - _smoothingFactor) + magnitude * _smoothingFactor;
          } else {
            _smoothedMagnitude = magnitude;
          }

          // Calculate deviation from baseline using smoothed value
          final deviation = _isCalibrated
              ? (_smoothedMagnitude - _baselineMagnitude).abs()
              : 0.0;

          // Calculate detection strength (0-100 scale)
          // Only register detection if deviation exceeds minimum threshold
          // Sensitivity range: 10-200 maps to detection ranges
          // sensitivity=50 → detect changes above ~5µT as significant
          // sensitivity=200 → detect changes above ~20µT as significant
          // sensitivity=10 → detect changes above ~1µT as significant (very sensitive)
          final detectionStrength = _isCalibrated
              ? (deviation < _minDetectionThreshold
                  ? 0.0
                  : math.min(100.0, ((deviation - _minDetectionThreshold) / (_sensitivity / 10)) * 100))
              : 0.0;

          // Auto-adjust baseline if readings are consistently low (no metal nearby)
          if (_isCalibrated && detectionStrength < 5.0) {
            _lowDetectionCount++;
            if (_lowDetectionCount > 30) {
              // After 30 consecutive low readings (~3 seconds), slowly adjust baseline
              _baselineMagnitude = _baselineMagnitude * 0.95 + _smoothedMagnitude * 0.05;
            }
          } else {
            _lowDetectionCount = 0;
          }

          // Update history and audio feedback after build completes
          if (_isCalibrated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateHistory(deviation);
                _updateBeepFrequency(detectionStrength);
              }
            });
          }

          // Determine detection level
          final detectionLevel = _getDetectionLevel(detectionStrength);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Calibration status
                if (_isCalibrated)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Calibrated Mode',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tap calibrate icon to start detection',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Main detector gauge
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: MetalDetectorGaugePainter(
                      strength: detectionStrength,
                      detectionLevel: detectionLevel,
                      onSurfaceColor: colorScheme.onSurface,
                      primaryColor: colorScheme.primary,
                      errorColor: colorScheme.error,
                    ),
                    child: Container(),
                  ),
                ),

                const SizedBox(height: 24),

                // Detection level indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: detectionLevel.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: detectionLevel.color, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        detectionLevel.icon,
                        color: detectionLevel.color,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        detectionLevel.label,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: detectionLevel.color,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Audio toggle
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              _audioEnabled ? Icons.volume_up : Icons.volume_off,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Haptic Feedback',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Vibration frequency increases near metal',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _audioEnabled,
                              onChanged: (value) {
                                setState(() {
                                  _audioEnabled = value;
                                  if (!value) {
                                    _beepTimer?.cancel();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Readings cards
                Row(
                  children: [
                    Expanded(
                      child: MeasurementCard(
                        label: 'Current',
                        value: '${deviation.toStringAsFixed(1)} µT',
                        icon: Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MeasurementCard(
                        label: 'Maximum',
                        value: '${_maxRecorded.toStringAsFixed(1)} µT',
                        icon: Icons.arrow_upward,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: MeasurementCard(
                        label: 'Baseline',
                        value: '${_baselineMagnitude.toStringAsFixed(1)} µT',
                        icon: Icons.straighten,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MeasurementCard(
                        label: 'Strength',
                        value: '${detectionStrength.toStringAsFixed(0)}%',
                        icon: Icons.signal_cellular_alt,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Sensitivity control
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sensitivity',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _sensitivity.toStringAsFixed(0),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _sensitivity,
                          min: 10,
                          max: 200,
                          divisions: 38,
                          onChanged: (value) {
                            setState(() => _sensitivity = value);
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Less Sensitive',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            Text(
                              'More Sensitive',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // History graph
                if (_history.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detection History',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 100,
                            child: CustomPaint(
                              painter: HistoryGraphPainter(
                                data: _history,
                                maxValue: _maxRecorded > 0 ? _maxRecorded : 1,
                                primaryColor: colorScheme.primary,
                                onSurfaceColor: colorScheme.onSurface,
                              ),
                              child: Container(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Instructions card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'How to Use',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInstructionRow(
                          '1. Calibrate in an area away from metal',
                        ),
                        _buildInstructionRow(
                          '2. Move device slowly along wall/surface',
                        ),
                        _buildInstructionRow('3. Watch for strength changes'),
                        _buildInstructionRow('4. Adjust sensitivity as needed'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructionRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text),
    );
  }

  DetectionLevel _getDetectionLevel(double strength) {
    if (strength < 10) {
      return DetectionLevel.none;
    } else if (strength < 30) {
      return DetectionLevel.weak;
    } else if (strength < 50) {
      return DetectionLevel.moderate;
    } else if (strength < 75) {
      return DetectionLevel.strong;
    } else {
      return DetectionLevel.veryStrong;
    }
  }
}

/// Detection level classification
enum DetectionLevel {
  none('No Detection', Icons.circle_outlined, Colors.grey),
  weak('Weak Signal', Icons.signal_cellular_alt_1_bar, Colors.blue),
  moderate('Moderate Signal', Icons.signal_cellular_alt_2_bar, Colors.orange),
  strong('Strong Signal', Icons.signal_cellular_alt, Colors.deepOrange),
  veryStrong('Metal Detected!', Icons.check_circle, Colors.red);

  final String label;
  final IconData icon;
  final Color color;

  const DetectionLevel(this.label, this.icon, this.color);
}

/// Custom painter for metal detector gauge
class MetalDetectorGaugePainter extends CustomPainter {
  final double strength; // 0-100
  final DetectionLevel detectionLevel;
  final Color onSurfaceColor;
  final Color primaryColor;
  final Color errorColor;

  MetalDetectorGaugePainter({
    required this.strength,
    required this.detectionLevel,
    required this.onSurfaceColor,
    required this.primaryColor,
    required this.errorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 40;

    // Draw background arc
    final backgroundPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75, // Start at 135°
      math.pi * 1.5, // Sweep 270°
      false,
      backgroundPaint,
    );

    // Draw strength arc
    if (strength > 0) {
      final strengthAngle = (strength / 100) * math.pi * 1.5;
      final gradient = SweepGradient(
        startAngle: math.pi * 0.75,
        endAngle: math.pi * 0.75 + strengthAngle,
        colors: [
          Colors.green,
          Colors.blue,
          Colors.orange,
          Colors.deepOrange,
          Colors.red,
        ],
      );

      final strengthPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.75,
        strengthAngle,
        false,
        strengthPaint,
      );
    }

    // Draw center circle
    final centerCirclePaint = Paint()
      ..color = detectionLevel.color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.5, centerCirclePaint);

    // Draw detection icon
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(detectionLevel.icon.codePoint),
        style: TextStyle(
          fontSize: 48,
          fontFamily: detectionLevel.icon.fontFamily,
          color: detectionLevel.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2 - 20,
      ),
    );

    // Draw percentage text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${strength.toStringAsFixed(0)}%',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: onSurfaceColor,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + 10),
    );
  }

  @override
  bool shouldRepaint(MetalDetectorGaugePainter oldDelegate) {
    return oldDelegate.strength != strength ||
        oldDelegate.detectionLevel != detectionLevel;
  }
}

/// Custom painter for history graph
class HistoryGraphPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;
  final Color primaryColor;
  final Color onSurfaceColor;

  HistoryGraphPainter({
    required this.data,
    required this.maxValue,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Draw baseline
    final baselinePaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      baselinePaint,
    );

    // Draw graph line
    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / math.max(1, data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedValue = (data[i] / maxValue).clamp(0.0, 1.0);
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);

    // Draw fill area
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(HistoryGraphPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.maxValue != maxValue;
  }
}
