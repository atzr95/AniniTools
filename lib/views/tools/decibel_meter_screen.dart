import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/sensor_viewmodel.dart';
import '../../widgets/measurement_card.dart';

/// Decibel Meter Tool - Measure sound levels with safety warnings
class DecibelMeterScreen extends StatefulWidget {
  const DecibelMeterScreen({super.key});

  @override
  State<DecibelMeterScreen> createState() => _DecibelMeterScreenState();
}

class _DecibelMeterScreenState extends State<DecibelMeterScreen> {
  final List<double> _history = [];
  static const int _maxHistoryLength = 100;

  // Running average for smoothing
  double _averageDb = 0.0;
  int _sampleCount = 0;

  void _updateMeasurements(double db) {
    setState(() {
      _sampleCount++;
      _averageDb = (_averageDb * (_sampleCount - 1) + db) / _sampleCount;

      _history.add(db);
      if (_history.length > _maxHistoryLength) {
        _history.removeAt(0);
      }
    });
  }

  void _resetMeasurements() {
    setState(() {
      _averageDb = 0.0;
      _sampleCount = 0;
      _history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Decibel Meter'),
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
          final currentDb = viewModel.decibel;

          // Update measurements continuously after build completes
          if (currentDb > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateMeasurements(currentDb);
              }
            });
          }

          // Determine safety level
          final safetyLevel = _getSafetyLevel(currentDb);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Main meter display
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
                    painter: DecibelMeterPainter(
                      decibels: currentDb,
                      safetyLevel: safetyLevel,
                      onSurfaceColor: colorScheme.onSurface,
                      primaryColor: colorScheme.primary,
                    ),
                    child: Container(),
                  ),
                ),

                const SizedBox(height: 24),

                // Safety warning card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: safetyLevel.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: safetyLevel.color,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(safetyLevel.icon, color: safetyLevel.color, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              safetyLevel.label,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: safetyLevel.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (safetyLevel.warningMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          safetyLevel.warningMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: safetyLevel.color,
                          ),
                        ),
                      ],
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
                        value: '${currentDb.toStringAsFixed(1)} dB',
                        icon: Icons.mic,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MeasurementCard(
                        label: 'Average',
                        value: '${_averageDb.toStringAsFixed(1)} dB',
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
                        label: 'Maximum',
                        value: _history.isEmpty
                            ? '0.0 dB'
                            : '${_history.reduce(math.max).toStringAsFixed(1)} dB',
                        icon: Icons.arrow_upward,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MeasurementCard(
                        label: 'Minimum',
                        value: _history.isEmpty
                            ? '-- dB'
                            : '${_history.reduce(math.min).toStringAsFixed(1)} dB',
                        icon: Icons.arrow_downward,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // History graph
                if (_history.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sound Level History',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 120,
                            child: CustomPaint(
                              painter: DecibelHistoryPainter(
                                data: _history,
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

                // Reference levels card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Sound Level Reference',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildReferenceRow('Whisper', '20-30 dB', Colors.green),
                        _buildReferenceRow('Library', '40 dB', Colors.green),
                        _buildReferenceRow('Normal Conversation', '60 dB', Colors.blue),
                        _buildReferenceRow('Busy Traffic', '70-80 dB', Colors.orange),
                        _buildReferenceRow('Alarm Clock', '80 dB', Colors.orange),
                        _buildReferenceRow('Motorcycle', '90 dB', Colors.deepOrange),
                        _buildReferenceRow('Chainsaw', '100 dB', Colors.red),
                        _buildReferenceRow('Rock Concert', '110 dB', Colors.red),
                        _buildReferenceRow('Thunder', '120 dB', Colors.red),
                        _buildReferenceRow('Pain Threshold', '130+ dB', Colors.red),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // OSHA exposure limits card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_outlined, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'OSHA Exposure Limits',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildExposureRow('85 dB', '8 hours'),
                        _buildExposureRow('90 dB', '2.5 hours'),
                        _buildExposureRow('95 dB', '47 minutes'),
                        _buildExposureRow('100 dB', '15 minutes'),
                        _buildExposureRow('105 dB', '5 minutes'),
                        _buildExposureRow('110 dB', '90 seconds'),
                        _buildExposureRow('115 dB', '30 seconds'),
                        const SizedBox(height: 12),
                        Text(
                          'Prolonged exposure above these levels can cause hearing damage',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
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

  Widget _buildReferenceRow(String source, String level, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(source),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 1),
            ),
            child: Text(
              level,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExposureRow(String level, String duration) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            level,
            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
          Text(
            duration,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  SafetyLevel _getSafetyLevel(double db) {
    if (db < 40) {
      return SafetyLevel.safe;
    } else if (db < 70) {
      return SafetyLevel.normal;
    } else if (db < 85) {
      return SafetyLevel.caution;
    } else if (db < 100) {
      return SafetyLevel.warningLevel;
    } else if (db < 120) {
      return SafetyLevel.danger;
    } else {
      return SafetyLevel.extreme;
    }
  }
}

/// Safety level classification
enum SafetyLevel {
  safe(
    'Safe',
    Icons.check_circle,
    Colors.green,
    null,
  ),
  normal(
    'Normal',
    Icons.info_outline,
    Colors.blue,
    'Comfortable sound level',
  ),
  caution(
    'Caution',
    Icons.warning_amber,
    Colors.orange,
    'May become uncomfortable with prolonged exposure',
  ),
  warningLevel(
    'Warning',
    Icons.warning,
    Colors.deepOrange,
    'Hearing protection recommended for prolonged exposure',
  ),
  danger(
    'Danger',
    Icons.error,
    Colors.red,
    'Use hearing protection! Risk of hearing damage',
  ),
  extreme(
    'EXTREME DANGER',
    Icons.dangerous,
    Colors.red,
    'IMMEDIATE hearing damage possible! Leave area or use protection!',
  );

  final String label;
  final IconData icon;
  final Color color;
  final String? warningMessage;

  const SafetyLevel(this.label, this.icon, this.color, this.warningMessage);
}

/// Custom painter for decibel meter gauge
class DecibelMeterPainter extends CustomPainter {
  final double decibels;
  final SafetyLevel safetyLevel;
  final Color onSurfaceColor;
  final Color primaryColor;

  DecibelMeterPainter({
    required this.decibels,
    required this.safetyLevel,
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

    // Draw decibel arc (0-140 dB scale)
    if (decibels > 0) {
      final normalizedDb = (decibels / 140).clamp(0.0, 1.0);
      final decibelAngle = normalizedDb * math.pi * 1.5;

      final gradient = SweepGradient(
        startAngle: math.pi * 0.75,
        endAngle: math.pi * 0.75 + math.pi * 1.5,
        colors: [
          Colors.green,
          Colors.blue,
          Colors.orange,
          Colors.deepOrange,
          Colors.red,
          Colors.red.shade900,
        ],
      );

      final decibelPaint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 0.75,
        decibelAngle,
        false,
        decibelPaint,
      );
    }

    // Draw center circle
    final centerCirclePaint = Paint()
      ..color = safetyLevel.color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.6, centerCirclePaint);

    // Draw decibel text
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${decibels.toStringAsFixed(1)}\ndB',
        style: TextStyle(
          fontSize: 36,
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

    // Draw scale markers
    _drawScaleMarkers(canvas, center, radius, onSurfaceColor);
  }

  void _drawScaleMarkers(Canvas canvas, Offset center, double radius, Color color) {
    final markerPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 2;

    final levels = [0, 20, 40, 60, 80, 100, 120, 140];

    for (final level in levels) {
      final normalizedLevel = level / 140;
      final angle = math.pi * 0.75 + normalizedLevel * math.pi * 1.5;

      final innerRadius = radius - 20;
      final outerRadius = radius + 10;

      final x1 = center.dx + math.cos(angle) * innerRadius;
      final y1 = center.dy + math.sin(angle) * innerRadius;
      final x2 = center.dx + math.cos(angle) * outerRadius;
      final y2 = center.dy + math.sin(angle) * outerRadius;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), markerPaint);

      // Draw level text
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$level',
          style: TextStyle(
            fontSize: 10,
            color: color.withValues(alpha: 0.5),
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final textRadius = outerRadius + 15;
      final textX = center.dx + math.cos(angle) * textRadius - textPainter.width / 2;
      final textY = center.dy + math.sin(angle) * textRadius - textPainter.height / 2;

      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(DecibelMeterPainter oldDelegate) {
    return oldDelegate.decibels != decibels ||
        oldDelegate.safetyLevel != safetyLevel;
  }
}

/// Custom painter for decibel history graph
class DecibelHistoryPainter extends CustomPainter {
  final List<double> data;
  final Color primaryColor;
  final Color onSurfaceColor;

  DecibelHistoryPainter({
    required this.data,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxDb = data.reduce(math.max);
    final minDb = data.reduce(math.min);
    final range = maxDb - minDb;

    // Draw baseline
    final baselinePaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      baselinePaint,
    );

    // Draw safety zones
    _drawSafetyZones(canvas, size, minDb, range);

    // Draw graph line
    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / math.max(1, data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedValue = range > 0 ? ((data[i] - minDb) / range) : 0.5;
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

  void _drawSafetyZones(Canvas canvas, Size size, double minDb, double range) {
    if (range <= 0) return;

    final zones = [
      (40.0, Colors.green),
      (70.0, Colors.blue),
      (85.0, Colors.orange),
      (100.0, Colors.red),
    ];

    for (final (threshold, color) in zones) {
      if (threshold >= minDb && threshold <= minDb + range) {
        final normalizedY = ((threshold - minDb) / range);
        final y = size.height - (normalizedY * size.height);

        final zonePaint = Paint()
          ..color = color.withValues(alpha: 0.1)
          ..strokeWidth = 1;

        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          zonePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DecibelHistoryPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
