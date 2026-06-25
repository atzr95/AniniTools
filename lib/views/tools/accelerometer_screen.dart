import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/sensor_viewmodel.dart';

// Shared style for section header labels.
const TextStyle _kLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  letterSpacing: 1.5,
);

/// Accelerometer Tool - Vehicle acceleration meter
/// Uses GPS for speed measurement and accelerometer for acceleration forces
class AccelerometerScreen extends StatefulWidget {
  const AccelerometerScreen({super.key});

  @override
  State<AccelerometerScreen> createState() => _AccelerometerScreenState();
}

class _AccelerometerScreenState extends State<AccelerometerScreen> {
  // Peak measurements
  double _peakAcceleration = 0.0; // m/s²
  double _peakDeceleration = 0.0; // m/s²
  double _topSpeed = 0.0; // km/h

  // History for graph
  final List<double> _accelerationHistory = [];
  final List<double> _speedHistory = [];
  static const int _maxHistoryLength = 100;

  // Smoothed acceleration for display
  double _smoothedAccel = 0.0;
  static const double _smoothingFactor = 0.3;

  double _lastAccelY = 0.0;
  double _lastGpsSpeedKmh = 0.0;

  // Threshold to filter out noise (m/s²)
  static const double _noiseThreshold = 0.3;

  // Timer for updating measurements
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Update at 10 FPS - sufficient for display and graph updates
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) {
        _updateMeasurements();
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _resetMeasurements() {
    setState(() {
      _peakAcceleration = 0.0;
      _peakDeceleration = 0.0;
      _topSpeed = 0.0;
      _smoothedAccel = 0.0;
      _accelerationHistory.clear();
      _speedHistory.clear();
    });
  }

  void _updateMeasurements() {
    final accelY = _lastAccelY;
    final speedKmh = _lastGpsSpeedKmh;

    // Filter noise from accelerometer
    final linearAccel = accelY.abs() > _noiseThreshold ? accelY : 0.0;

    // Smooth the acceleration for display
    _smoothedAccel = _smoothedAccel * (1 - _smoothingFactor) + linearAccel * _smoothingFactor;

    setState(() {
      // Update peak acceleration
      if (linearAccel > _peakAcceleration) {
        _peakAcceleration = linearAccel;
      }
      if (linearAccel < 0 && linearAccel.abs() > _peakDeceleration) {
        _peakDeceleration = linearAccel.abs();
      }

      // Update top speed from GPS
      if (speedKmh > _topSpeed) {
        _topSpeed = speedKmh;
      }

      // Update acceleration history
      _accelerationHistory.add(linearAccel);
      if (_accelerationHistory.length > _maxHistoryLength) {
        _accelerationHistory.removeAt(0);
      }

      // Update speed history from GPS
      _speedHistory.add(speedKmh);
      if (_speedHistory.length > _maxHistoryLength) {
        _speedHistory.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceleration Meter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: _resetMeasurements,
          ),
        ],
      ),
      body: Consumer<SensorViewModel>(
        builder: (context, viewModel, child) {
          if (!viewModel.isSensorAvailable('accelerometer')) {
            return const Center(
              child: Text('Accelerometer not available'),
            );
          }

          // Store latest values for the timer to use
          _lastAccelY = viewModel.linearAccelY;
          _lastGpsSpeedKmh = viewModel.gpsSpeedKmh;

          final currentSpeedKmh = viewModel.gpsSpeedKmh;
          final currentSpeedMs = viewModel.gpsSpeed;
          final hasGps = viewModel.isSensorAvailable('gps');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Current Speed Display (GPS-based)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'CURRENT SPEED',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              hasGps ? Icons.gps_fixed : Icons.gps_off,
                              size: 16,
                              color: hasGps ? Colors.green : Colors.orange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currentSpeedKmh.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'km/h',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${currentSpeedMs.toStringAsFixed(2)} m/s',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        if (!hasGps) ...[
                          const SizedBox(height: 8),
                          Text(
                            'GPS not available - enable location for speed',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Current Acceleration
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'CURRENT ACCELERATION',
                          style: _kLabelStyle,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _smoothedAccel.toStringAsFixed(2),
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: _smoothedAccel > 0.3
                                    ? Colors.green
                                    : _smoothedAccel < -0.3
                                        ? Colors.red
                                        : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'm/s\u00B2',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _smoothedAccel.abs() > 0.5
                              ? (_smoothedAccel > 0
                                  ? 'Accelerating'
                                  : 'Braking')
                              : 'Steady',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Peak Measurements
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PEAK MEASUREMENTS',
                          style: _kLabelStyle,
                        ),
                        const SizedBox(height: 16),
                        _buildPeakRow(
                          'Top Speed',
                          '${_topSpeed.toStringAsFixed(1)} km/h',
                          Icons.speed,
                          Colors.blue,
                        ),
                        const Divider(height: 24),
                        _buildPeakRow(
                          'Peak Acceleration',
                          '${_peakAcceleration.toStringAsFixed(2)} m/s\u00B2',
                          Icons.arrow_upward,
                          Colors.green,
                        ),
                        const Divider(height: 24),
                        _buildPeakRow(
                          'Peak Braking',
                          '${_peakDeceleration.toStringAsFixed(2)} m/s\u00B2',
                          Icons.arrow_downward,
                          Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Acceleration History Graph
                if (_accelerationHistory.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACCELERATION HISTORY',
                            style: _kLabelStyle,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 150,
                            child: CustomPaint(
                              painter: _AccelerationGraphPainter(
                                _accelerationHistory,
                                colorScheme,
                              ),
                              size: const Size(double.infinity, 150),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Speed History Graph
                if (_speedHistory.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SPEED HISTORY',
                            style: _kLabelStyle,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 150,
                            child: CustomPaint(
                              painter: _SpeedGraphPainter(
                                _speedHistory,
                                colorScheme,
                              ),
                              size: const Size(double.infinity, 150),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Reference Guide
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'REFERENCE GUIDE',
                          style: _kLabelStyle,
                        ),
                        const SizedBox(height: 16),
                        _buildReferenceRow(
                            'City car (0-100 km/h)', '~10-15 sec', '~2-3 m/s\u00B2'),
                        _buildReferenceRow(
                            'Sports car (0-100 km/h)', '~3-5 sec', '~5-8 m/s\u00B2'),
                        _buildReferenceRow(
                            'Supercar (0-100 km/h)', '<3 sec', '>10 m/s\u00B2'),
                        const Divider(height: 16),
                        _buildReferenceRow('Normal braking', '', '~3-4 m/s\u00B2'),
                        _buildReferenceRow('Emergency braking', '', '~7-10 m/s\u00B2'),
                        const Divider(height: 16),
                        _buildReferenceRow('Train acceleration', '', '~0.5-1.5 m/s\u00B2'),
                        _buildReferenceRow('Elevator', '', '~1-2 m/s\u00B2'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Instructions
                Card(
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: colorScheme.onPrimaryContainer),
                            const SizedBox(width: 8),
                            Text(
                              'HOW TO USE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.5,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. Place phone flat with screen facing up\n'
                          '2. Orient top of phone toward direction of travel\n'
                          '3. Speed is measured via GPS (requires location)\n'
                          '4. Acceleration is measured via accelerometer\n'
                          '5. Use reset to clear peak measurements',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.9),
                            height: 1.6,
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

  Widget _buildPeakRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceRow(String label, String time, String accel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (time.isNotEmpty)
            Expanded(
              flex: 2,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          Expanded(
            flex: 2,
            child: Text(
              accel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for acceleration graph
class _AccelerationGraphPainter extends CustomPainter {
  final List<double> data;
  final ColorScheme colorScheme;

  _AccelerationGraphPainter(this.data, this.colorScheme);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final maxValue = data.map((e) => e.abs()).reduce(math.max);
    final minValue = data.reduce(math.min);
    final range = maxValue - minValue;

    if (range == 0) return;

    final stepX = size.width / (data.length - 1);
    final path = Path();

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedValue = (data[i] - minValue) / range;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw zero line
    final zeroY = size.height - ((-minValue) / range * size.height);
    final zeroPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroPaint);

    // Draw graph
    paint.color = colorScheme.primary;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AccelerationGraphPainter oldDelegate) {
    if (oldDelegate.data.length != data.length) return true;
    for (var i = 0; i < data.length; i++) {
      if (oldDelegate.data[i] != data[i]) return true;
    }
    return false;
  }
}

// Custom painter for speed graph
class _SpeedGraphPainter extends CustomPainter {
  final List<double> data;
  final ColorScheme colorScheme;

  _SpeedGraphPainter(this.data, this.colorScheme);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final maxValue = data.reduce(math.max);
    if (maxValue == 0) return;

    final stepX = size.width / (data.length - 1);
    final path = Path();

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - (data[i] / maxValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Fill area under curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SpeedGraphPainter oldDelegate) {
    if (oldDelegate.data.length != data.length) return true;
    for (var i = 0; i < data.length; i++) {
      if (oldDelegate.data[i] != data[i]) return true;
    }
    return false;
  }
}
