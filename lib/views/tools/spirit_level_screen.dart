import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/sensor_viewmodel.dart';

/// Spirit Level Tool - 2D bubble level for checking surface flatness
class SpiritLevelScreen extends StatefulWidget {
  const SpiritLevelScreen({super.key});

  @override
  State<SpiritLevelScreen> createState() => _SpiritLevelScreenState();
}

class _SpiritLevelScreenState extends State<SpiritLevelScreen> {
  bool _isCalibrated = false;
  double _calibrationPitch = 0.0;
  double _calibrationRoll = 0.0;

  // Smoothing for bubble position to reduce jitter
  double _smoothedPitch = 0.0;
  double _smoothedRoll = 0.0;
  static const double _smoothingFactor = 0.15; // Lower = smoother (0.15 = strong smoothing)

  @override
  void initState() {
    super.initState();
    // Auto-calibrate on start after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        final viewModel = Provider.of<SensorViewModel>(context, listen: false);
        _calibrate(viewModel);
      }
    });
  }

  void _calibrate(SensorViewModel viewModel) {
    setState(() {
      _isCalibrated = true;
      _calibrationPitch = viewModel.pitch;
      _calibrationRoll = viewModel.roll;
      _smoothedPitch = 0.0;
      _smoothedRoll = 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calibrated to current surface')),
    );
  }

  void _resetCalibration() {
    setState(() {
      _isCalibrated = false;
      _calibrationPitch = 0.0;
      _calibrationRoll = 0.0;
      _smoothedPitch = 0.0;
      _smoothedRoll = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spirit Level'),
        actions: [
          Consumer<SensorViewModel>(
            builder: (context, viewModel, _) => IconButton(
              icon: const Icon(Icons.my_location),
              tooltip: 'Calibrate',
              onPressed: () => _calibrate(viewModel),
            ),
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
          // Apply calibration offsets
          final adjustedPitch = viewModel.pitch - _calibrationPitch;
          final adjustedRoll = viewModel.roll - _calibrationRoll;

          // Apply exponential smoothing to reduce jitter
          // Only smooth if we have previous values, otherwise initialize
          if (_isCalibrated && (_smoothedPitch.abs() > 0.001 || _smoothedRoll.abs() > 0.001)) {
            _smoothedPitch = _smoothedPitch * (1 - _smoothingFactor) + adjustedPitch * _smoothingFactor;
            _smoothedRoll = _smoothedRoll * (1 - _smoothingFactor) + adjustedRoll * _smoothingFactor;
          } else {
            _smoothedPitch = adjustedPitch;
            _smoothedRoll = adjustedRoll;
          }

          // Convert radians to degrees (using smoothed values)
          final pitchDegrees = _smoothedPitch * 180 / math.pi;
          final rollDegrees = _smoothedRoll * 180 / math.pi;

          // Check if level (within 3 degrees for larger tolerance area)
          final isLevel = pitchDegrees.abs() < 3.0 && rollDegrees.abs() < 3.0;

          return Column(
            children: [
              // Calibration status
              if (_isCalibrated)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: colorScheme.primaryContainer,
                  child: Text(
                    'Calibrated Mode',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Main bubble level display
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(24),
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
                    painter: SpiritLevelPainter(
                      pitch: _smoothedPitch,
                      roll: _smoothedRoll,
                      isLevel: isLevel,
                      onSurfaceColor: colorScheme.onSurface,
                      primaryColor: colorScheme.primary,
                      errorColor: colorScheme.error,
                    ),
                    child: Container(),
                  ),
                ),
              ),

              // Angle readings
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Level indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isLevel
                            ? Colors.green.withValues(alpha: 0.2)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isLevel ? Colors.green : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isLevel ? Icons.check_circle : Icons.circle_outlined,
                            color: isLevel ? Colors.green : colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isLevel ? 'LEVEL' : 'NOT LEVEL',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isLevel ? Colors.green : colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pitch and Roll readings
                    Row(
                      children: [
                        Expanded(
                          child: _buildAngleCard(
                            context,
                            'Pitch',
                            pitchDegrees,
                            Icons.swap_vert,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildAngleCard(
                            context,
                            'Roll',
                            rollDegrees,
                            Icons.swap_horiz,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAngleCard(
    BuildContext context,
    String label,
    double degrees,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${degrees.toStringAsFixed(1)}°',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the spirit level bubble
class SpiritLevelPainter extends CustomPainter {
  final double pitch;
  final double roll;
  final bool isLevel;
  final Color onSurfaceColor;
  final Color primaryColor;
  final Color errorColor;

  SpiritLevelPainter({
    required this.pitch,
    required this.roll,
    required this.isLevel,
    required this.onSurfaceColor,
    required this.primaryColor,
    required this.errorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 40;

    // Draw outer circle (tube)
    final outerPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, outerPaint);

    // Draw crosshairs
    final crosshairPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      crosshairPaint,
    );

    // Draw center target
    final targetPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, 20, targetPaint);
    canvas.drawCircle(center, 40, targetPaint);

    // Calculate bubble position
    // Pitch (forward/backward tilt) affects Y position
    // Roll (left/right tilt) affects X position
    // Negative because bubble moves opposite to tilt direction
    final maxOffset = radius - 30;
    final pitchDegrees = pitch * 180 / math.pi;
    final rollDegrees = roll * 180 / math.pi;

    // Scale: ±10 degrees = full radius movement
    final bubbleX = center.dx - (rollDegrees * maxOffset / 10);
    final bubbleY = center.dy - (pitchDegrees * maxOffset / 10);

    // Constrain bubble to circle
    final dx = bubbleX - center.dx;
    final dy = bubbleY - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final Offset bubbleCenter;
    if (distance > maxOffset) {
      final angle = math.atan2(dy, dx);
      bubbleCenter = Offset(
        center.dx + math.cos(angle) * maxOffset,
        center.dy + math.sin(angle) * maxOffset,
      );
    } else {
      bubbleCenter = Offset(bubbleX, bubbleY);
    }

    // Draw bubble shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(bubbleCenter.translate(2, 2), 25, shadowPaint);

    // Draw bubble
    final bubblePaint = Paint()
      ..color = isLevel ? primaryColor : errorColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(bubbleCenter, 25, bubblePaint);

    // Draw bubble highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5);
    canvas.drawCircle(bubbleCenter.translate(-6, -6), 10, highlightPaint);

    // Draw center indicator
    final centerDotPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, centerDotPaint);
  }

  @override
  bool shouldRepaint(SpiritLevelPainter oldDelegate) {
    return oldDelegate.pitch != pitch ||
        oldDelegate.roll != roll ||
        oldDelegate.isLevel != isLevel;
  }
}
