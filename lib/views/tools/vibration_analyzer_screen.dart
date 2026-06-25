import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/sensor_viewmodel.dart';
import '../../widgets/measurement_card.dart';

/// Vibration Analyzer Tool - Analyze vibrations for diagnostics
class VibrationAnalyzerScreen extends StatefulWidget {
  const VibrationAnalyzerScreen({super.key});

  @override
  State<VibrationAnalyzerScreen> createState() =>
      _VibrationAnalyzerScreenState();
}

class _VibrationAnalyzerScreenState extends State<VibrationAnalyzerScreen> {
  double _peakVibration = 0.0;
  double _averageVibration = 0.0;
  int _sampleCount = 0;

  final List<double> _vibrationHistory = [];
  static const int _maxHistoryLength = 200;

  // Frequency analysis (simplified)
  final Map<String, int> _frequencyBuckets = {
    'Very Low (0-5 Hz)': 0,
    'Low (5-20 Hz)': 0,
    'Medium (20-50 Hz)': 0,
    'High (50-100 Hz)': 0,
    'Very High (100+ Hz)': 0,
  };

  Timer? _analysisTimer;

  @override
  void initState() {
    super.initState();
    _startAnalysisTimer();
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    super.dispose();
  }

  void _startAnalysisTimer() {
    // Update UI at 20 Hz
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {}); // Trigger rebuild for real-time updates
      }
    });
  }

  void _resetMeasurements() {
    setState(() {
      _peakVibration = 0.0;
      _averageVibration = 0.0;
      _sampleCount = 0;
      _vibrationHistory.clear();
      _frequencyBuckets.updateAll((key, value) => 0);
    });
  }

  void _updateMeasurements(double vibration, double frequency) {
    setState(() {
      // Update peak
      if (vibration > _peakVibration) {
        _peakVibration = vibration;
      }

      // Update average
      _sampleCount++;
      _averageVibration =
          (_averageVibration * (_sampleCount - 1) + vibration) / _sampleCount;

      // Update history
      _vibrationHistory.add(vibration);
      if (_vibrationHistory.length > _maxHistoryLength) {
        _vibrationHistory.removeAt(0);
      }

      // Update frequency bucket
      _updateFrequencyBucket(frequency);
    });
  }

  void _updateFrequencyBucket(double frequency) {
    if (frequency < 5) {
      _frequencyBuckets['Very Low (0-5 Hz)'] =
          _frequencyBuckets['Very Low (0-5 Hz)']! + 1;
    } else if (frequency < 20) {
      _frequencyBuckets['Low (5-20 Hz)'] = _frequencyBuckets['Low (5-20 Hz)']! + 1;
    } else if (frequency < 50) {
      _frequencyBuckets['Medium (20-50 Hz)'] =
          _frequencyBuckets['Medium (20-50 Hz)']! + 1;
    } else if (frequency < 100) {
      _frequencyBuckets['High (50-100 Hz)'] =
          _frequencyBuckets['High (50-100 Hz)']! + 1;
    } else {
      _frequencyBuckets['Very High (100+ Hz)'] =
          _frequencyBuckets['Very High (100+ Hz)']! + 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibration Analyzer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: _resetMeasurements,
          ),
        ],
      ),
      body: Consumer<SensorViewModel>(
        builder: (context, viewModel, _) {
          // Calculate vibration magnitude from acceleration
          final accelX = viewModel.accelX;
          final accelY = viewModel.accelY;
          final accelZ = viewModel.accelZ;

          // Remove gravity component (9.8 m/s²) and calculate magnitude
          final vibration = math.sqrt(
            accelX * accelX + accelY * accelY + (accelZ - 9.8) * (accelZ - 9.8),
          );

          // Estimate frequency (simplified - based on change rate)
          // In a real implementation, you'd use FFT
          final frequency = _estimateFrequency(vibration);

          // Update measurements continuously after build completes
          if (vibration > 0.1) {
            // Threshold to ignore noise
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateMeasurements(vibration, frequency);
              }
            });
          }

          // Determine vibration level
          final vibrationLevel = _getVibrationLevel(vibration);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Main vibration gauge
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
                    painter: VibrationGaugePainter(
                      vibration: vibration,
                      vibrationLevel: vibrationLevel,
                      onSurfaceColor: colorScheme.onSurface,
                      primaryColor: colorScheme.primary,
                    ),
                    child: Container(),
                  ),
                ),

                const SizedBox(height: 24),

                // Vibration level indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: vibrationLevel.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: vibrationLevel.color,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(vibrationLevel.icon, color: vibrationLevel.color, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vibrationLevel.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: vibrationLevel.color,
                              ),
                            ),
                            if (vibrationLevel.description != null)
                              Text(
                                vibrationLevel.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: vibrationLevel.color,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Measurement cards
                Row(
                  children: [
                    Expanded(
                      child: MeasurementCard(
                        label: 'Current',
                        value: '${vibration.toStringAsFixed(2)} m/s²',
                        icon: Icons.vibration,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MeasurementCard(
                        label: 'Average',
                        value: '${_averageVibration.toStringAsFixed(2)} m/s²',
                        icon: Icons.trending_flat,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: MeasurementCard(
                        label: 'Peak',
                        value: '${_peakVibration.toStringAsFixed(2)} m/s²',
                        icon: Icons.arrow_upward,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MeasurementCard(
                        label: 'Frequency',
                        value: '${frequency.toStringAsFixed(1)} Hz',
                        icon: Icons.graphic_eq,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Vibration history graph
                if (_vibrationHistory.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vibration History',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 120,
                            child: CustomPaint(
                              painter: VibrationHistoryPainter(
                                data: _vibrationHistory,
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
                  const SizedBox(height: 16),
                ],

                // Frequency distribution
                if (_sampleCount > 0) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Frequency Distribution',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._frequencyBuckets.entries.map((entry) {
                            final percentage =
                                (_sampleCount > 0 ? (entry.value / _sampleCount) * 100 : 0.0);
                            return _buildFrequencyBar(
                              context,
                              entry.key,
                              percentage,
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Diagnostic guide
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.engineering, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Diagnostic Guide',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDiagnosticRow(
                          'Appliances',
                          '< 1 m/s²',
                          'Normal operation',
                        ),
                        _buildDiagnosticRow(
                          'Car Engine (Idle)',
                          '0.5-2 m/s²',
                          'Smooth running',
                        ),
                        _buildDiagnosticRow(
                          'Car Engine (Rev)',
                          '2-5 m/s²',
                          'Normal operation',
                        ),
                        _buildDiagnosticRow(
                          'Washing Machine',
                          '1-3 m/s²',
                          'Balanced load',
                        ),
                        _buildDiagnosticRow(
                          'High Vibration',
                          '> 5 m/s²',
                          'Check for issues',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Usage tips
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tips_and_updates, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Usage Tips',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTipRow('Place phone firmly on vibrating surface'),
                        _buildTipRow('Start recording before starting equipment'),
                        _buildTipRow('Record for 10-30 seconds for best results'),
                        _buildTipRow('Compare readings to normal baseline'),
                        _buildTipRow('Look for sudden changes in patterns'),
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

  Widget _buildFrequencyBar(
    BuildContext context,
    String label,
    double percentage,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(String source, String range, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(source, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              range,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              status,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  // ponytail: rough magnitude->frequency estimate, NOT a real FFT. The phone
  // accelerometer can't sample fast enough for true frequency analysis here, so
  // this drives the "Frequency" card / distribution as a coarse indicator only.
  // Upgrade path: buffer raw accel samples and run an FFT if accuracy matters.
  double _estimateFrequency(double vibration) {
    if (vibration < 0.5) return 5.0;
    if (vibration < 1.0) return 15.0;
    if (vibration < 2.0) return 30.0;
    if (vibration < 4.0) return 60.0;
    return 90.0;
  }

  VibrationLevel _getVibrationLevel(double vibration) {
    if (vibration < 0.5) {
      return VibrationLevel.minimal;
    } else if (vibration < 1.5) {
      return VibrationLevel.low;
    } else if (vibration < 3.0) {
      return VibrationLevel.moderate;
    } else if (vibration < 5.0) {
      return VibrationLevel.high;
    } else {
      return VibrationLevel.extreme;
    }
  }
}

/// Vibration level classification
enum VibrationLevel {
  minimal(
    'Minimal',
    Icons.check_circle,
    Colors.green,
    'Normal operation',
  ),
  low(
    'Low',
    Icons.info_outline,
    Colors.blue,
    'Typical for smooth operation',
  ),
  moderate(
    'Moderate',
    Icons.warning_amber,
    Colors.orange,
    'Normal for heavy machinery',
  ),
  high(
    'High',
    Icons.warning,
    Colors.deepOrange,
    'May indicate wear or imbalance',
  ),
  extreme(
    'Extreme',
    Icons.dangerous,
    Colors.red,
    'Check for mechanical issues!',
  );

  final String label;
  final IconData icon;
  final Color color;
  final String? description;

  const VibrationLevel(this.label, this.icon, this.color, this.description);
}

/// Custom painter for vibration gauge
class VibrationGaugePainter extends CustomPainter {
  final double vibration;
  final VibrationLevel vibrationLevel;
  final Color onSurfaceColor;
  final Color primaryColor;

  VibrationGaugePainter({
    required this.vibration,
    required this.vibrationLevel,
    required this.onSurfaceColor,
    required this.primaryColor,
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

    // Draw vibration arc (0-10 m/s² scale)
    if (vibration > 0) {
      final normalizedVibration = (vibration / 10).clamp(0.0, 1.0);
      final vibrationAngle = normalizedVibration * math.pi * 1.5;

      final gradient = SweepGradient(
        startAngle: math.pi * 0.75,
        endAngle: math.pi * 0.75 + math.pi * 1.5,
        colors: [
          Colors.green,
          Colors.blue,
          Colors.orange,
          Colors.deepOrange,
          Colors.red,
        ],
      );

      final vibrationPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.75,
        vibrationAngle,
        false,
        vibrationPaint,
      );
    }

    // Draw center circle
    final centerCirclePaint = Paint()
      ..color = vibrationLevel.color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.6, centerCirclePaint);

    // Draw vibration text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${vibration.toStringAsFixed(2)}\nm/s²',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: onSurfaceColor,
          fontFamily: 'monospace',
          height: 1.2,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(VibrationGaugePainter oldDelegate) {
    return oldDelegate.vibration != vibration ||
        oldDelegate.vibrationLevel != vibrationLevel;
  }
}

/// Custom painter for vibration history graph
class VibrationHistoryPainter extends CustomPainter {
  final List<double> data;
  final Color primaryColor;
  final Color onSurfaceColor;

  VibrationHistoryPainter({
    required this.data,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVibration = data.reduce(math.max);

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
      final normalizedValue =
          maxVibration > 0 ? (data[i] / maxVibration).clamp(0.0, 1.0) : 0.0;
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
  bool shouldRepaint(VibrationHistoryPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
