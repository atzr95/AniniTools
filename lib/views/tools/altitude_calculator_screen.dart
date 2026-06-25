import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/sensor_viewmodel.dart';
import '../../widgets/measurement_card.dart';

/// Altitude Calculator Tool - Track elevation using barometer and GPS
class AltitudeCalculatorScreen extends StatefulWidget {
  const AltitudeCalculatorScreen({super.key});

  @override
  State<AltitudeCalculatorScreen> createState() =>
      _AltitudeCalculatorScreenState();
}

class _AltitudeCalculatorScreenState extends State<AltitudeCalculatorScreen> {
  double _seaLevelPressure = 1013.25; // Standard atmospheric pressure at sea level
  bool _useManualSeaLevel = false;
  bool _isCalibrated = false;

  final List<AltitudeReading> _history = [];
  static const int _maxHistoryLength = 100;

  // Pressure trend tracking
  final List<double> _pressureHistory = [];
  static const int _pressureTrendLength = 20;

  void _updateHistory(double altitude, double pressure, double gpsAltitude) {
    setState(() {
      _history.add(AltitudeReading(
        timestamp: DateTime.now(),
        baroAltitude: altitude,
        gpsAltitude: gpsAltitude,
        pressure: pressure,
      ));
      if (_history.length > _maxHistoryLength) {
        _history.removeAt(0);
      }

      _pressureHistory.add(pressure);
      if (_pressureHistory.length > _pressureTrendLength) {
        _pressureHistory.removeAt(0);
      }
    });
  }

  String _getPressureTrend() {
    if (_pressureHistory.length < 2) return 'Insufficient data';

    final oldPressure = _pressureHistory.first;
    final newPressure = _pressureHistory.last;
    final diff = newPressure - oldPressure;

    if (diff.abs() < 0.5) {
      return 'Stable';
    } else if (diff > 0) {
      return 'Rising (${diff.toStringAsFixed(1)} hPa)';
    } else {
      return 'Falling (${diff.abs().toStringAsFixed(1)} hPa)';
    }
  }

  String _getWeatherPrediction() {
    if (_pressureHistory.length < 2) return 'Need more data';

    final oldPressure = _pressureHistory.first;
    final newPressure = _pressureHistory.last;
    final diff = newPressure - oldPressure;

    if (diff > 2.0) {
      return 'Improving weather expected';
    } else if (diff > 0.5) {
      return 'Weather likely to improve';
    } else if (diff < -2.0) {
      return 'Storm or rain likely';
    } else if (diff < -0.5) {
      return 'Weather may deteriorate';
    } else {
      return 'Stable conditions';
    }
  }

  void _calibrateFromGPS(double gpsAltitude, double currentPressure) {
    if (currentPressure <= 0 || gpsAltitude == 0.0) return;

    // Back-calculate sea level pressure: P0 = P / (1 - h/44330)^5.255
    final ratio = 1 - gpsAltitude / 44330;
    if (ratio <= 0) return;
    final calculatedSeaLevel = currentPressure / math.pow(ratio, 5.255);

    setState(() {
      _seaLevelPressure = calculatedSeaLevel;
      _useManualSeaLevel = true;
      _isCalibrated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Altitude Calculator'),
        actions: [
          Consumer<SensorViewModel>(
            builder: (context, viewModel, _) {
              return IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Calibrate from GPS',
                onPressed: () {
                  final pressure = viewModel.pressure;
                  final gpsAltitude = viewModel.altitude;
                  if (pressure <= 0 || gpsAltitude == 0.0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Cannot calibrate: waiting for GPS and pressure data',
                        ),
                      ),
                    );
                    return;
                  }
                  _calibrateFromGPS(gpsAltitude, pressure);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Calibrated! Sea level pressure: ${_seaLevelPressure.toStringAsFixed(2)} hPa',
                      ),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: Consumer<SensorViewModel>(
        builder: (context, viewModel, _) {
          // Get current readings
          final pressure = viewModel.pressure;
          final gpsAltitude = viewModel.altitude;
          final latitude = viewModel.latitude;
          final longitude = viewModel.longitude;

          // Calculate barometric altitude
          final seaLevel = _useManualSeaLevel ? _seaLevelPressure : 1013.25;
          final baroAltitude = _calculateAltitude(pressure, seaLevel);

          // Update history after build completes
          if (pressure > 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateHistory(baroAltitude, pressure, gpsAltitude);
            });
          }

          final pressureTrend = _getPressureTrend();
          final weatherPrediction = _getWeatherPrediction();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main altitude display
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.terrain,
                              color: colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Current Altitude',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '${gpsAltitude.toStringAsFixed(1)} m',
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(gpsAltitude * 3.28084).toStringAsFixed(1)} ft',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'GPS Altitude',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Comparison cards
                Row(
                  children: [
                    Expanded(
                      child: MeasurementCard(
                        label: 'Barometric',
                        value: '${baroAltitude.toStringAsFixed(1)} m',
                        icon: Icons.speed,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MeasurementCard(
                        label: 'Difference',
                        value:
                            '${(baroAltitude - gpsAltitude).abs().toStringAsFixed(1)} m',
                        icon: Icons.compare_arrows,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Pressure and coordinates
                Row(
                  children: [
                    Expanded(
                      child: MeasurementCard(
                        label: 'Pressure',
                        value: '${pressure.toStringAsFixed(1)} hPa',
                        icon: Icons.speed,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: MeasurementCard(
                        label: 'Sea Level',
                        value: '${seaLevel.toStringAsFixed(1)} hPa',
                        icon: Icons.water,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Pressure trend card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pressure Trend',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildTrendRow(context, 'Trend', pressureTrend),
                        _buildTrendRow(context, 'Forecast', weatherPrediction),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Location card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.place, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Location',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildLocationRow(
                          context,
                          'Latitude',
                          '${latitude.toStringAsFixed(6)}°',
                        ),
                        _buildLocationRow(
                          context,
                          'Longitude',
                          '${longitude.toStringAsFixed(6)}°',
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
                            'Altitude History',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 150,
                            child: CustomPaint(
                              painter: AltitudeHistoryPainter(
                                history: _history,
                                primaryColor: colorScheme.primary,
                                secondaryColor: colorScheme.secondary,
                                onSurfaceColor: colorScheme.onSurface,
                              ),
                              child: Container(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLegendItem(
                                'Barometric',
                                colorScheme.primary,
                              ),
                              const SizedBox(width: 16),
                              _buildLegendItem(
                                'GPS',
                                colorScheme.secondary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Information card
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
                              'About Altitude Calculation',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'GPS altitude is the primary display, measured by satellite',
                        ),
                        _buildInfoRow(
                          'Barometric altitude uses air pressure (requires calibration)',
                        ),
                        _buildInfoRow(
                          'Tap the calibrate button to sync barometric with GPS',
                        ),
                        _buildInfoRow(
                          'After calibration, barometric readings track small changes well',
                        ),
                        _buildInfoRow(
                          'Pressure trends can help predict weather changes',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Altitude reference card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.landscape, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Notable Elevations',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildReferenceRow('Sea Level', '0 m'),
                        _buildReferenceRow('Denver, CO', '1,609 m'),
                        _buildReferenceRow('La Paz, Bolivia', '3,640 m'),
                        _buildReferenceRow('Mt. Everest Base Camp', '5,364 m'),
                        _buildReferenceRow('Mt. Everest Summit', '8,849 m'),
                        _buildReferenceRow('Commercial Aircraft', '10,000-12,000 m'),
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

  Widget _buildTrendRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String text) {
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

  Widget _buildReferenceRow(String location, String altitude) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(location)),
          Text(
            altitude,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  double _calculateAltitude(double pressure, double seaLevelPressure) {
    if (pressure <= 0 || seaLevelPressure <= 0) return 0.0;

    // Standard atmosphere formula
    // h = 44330 * (1 - (P/P0)^(1/5.255))
    return (44330 * (1 - math.pow(pressure / seaLevelPressure, 1 / 5.255))).toDouble();
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Altitude Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer<SensorViewModel>(
                    builder: (context, viewModel, _) {
                      return FilledButton.icon(
                        icon: const Icon(Icons.tune),
                        label: const Text('Calibrate from GPS'),
                        onPressed: () {
                          final pressure = viewModel.pressure;
                          final gpsAlt = viewModel.altitude;
                          if (pressure <= 0 || gpsAlt == 0.0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Cannot calibrate: waiting for GPS and pressure data',
                                ),
                              ),
                            );
                            return;
                          }
                          _calibrateFromGPS(gpsAlt, pressure);
                          setDialogState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Calibrated! Sea level pressure: ${_seaLevelPressure.toStringAsFixed(2)} hPa',
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (_isCalibrated) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Calibrated sea level: ${_seaLevelPressure.toStringAsFixed(2)} hPa',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Manual Sea Level Pressure'),
                    subtitle: Text(
                      _useManualSeaLevel
                          ? 'Using custom value'
                          : 'Using standard (1013.25 hPa)',
                    ),
                    value: _useManualSeaLevel,
                    onChanged: (value) {
                      setDialogState(() {
                        setState(() {
                          _useManualSeaLevel = value;
                          if (!value) _isCalibrated = false;
                        });
                      });
                    },
                  ),
                  if (_useManualSeaLevel) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Sea Level Pressure: ${_seaLevelPressure.toStringAsFixed(2)} hPa',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      value: _seaLevelPressure.clamp(950.0, 1050.0),
                      min: 950,
                      max: 1050,
                      divisions: 100,
                      label: _seaLevelPressure.toStringAsFixed(1),
                      onChanged: (value) {
                        setDialogState(() {
                          setState(() {
                            _seaLevelPressure = value;
                          });
                        });
                      },
                    ),
                    const Text(
                      'Tip: Check local weather station for accurate sea level pressure',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Data class for altitude readings
class AltitudeReading {
  final DateTime timestamp;
  final double baroAltitude;
  final double gpsAltitude;
  final double pressure;

  AltitudeReading({
    required this.timestamp,
    required this.baroAltitude,
    required this.gpsAltitude,
    required this.pressure,
  });
}

/// Custom painter for altitude history graph
class AltitudeHistoryPainter extends CustomPainter {
  final List<AltitudeReading> history;
  final Color primaryColor;
  final Color secondaryColor;
  final Color onSurfaceColor;

  AltitudeHistoryPainter({
    required this.history,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    // Find min/max for scaling
    double minAlt = double.infinity;
    double maxAlt = double.negativeInfinity;

    for (final reading in history) {
      minAlt = math.min(minAlt, math.min(reading.baroAltitude, reading.gpsAltitude));
      maxAlt = math.max(maxAlt, math.max(reading.baroAltitude, reading.gpsAltitude));
    }

    final range = maxAlt - minAlt;
    if (range == 0) return;

    // Draw baseline
    final baselinePaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      baselinePaint,
    );

    // Draw barometric altitude line
    _drawLine(
      canvas,
      size,
      history.map((r) => r.baroAltitude).toList(),
      minAlt,
      range,
      primaryColor,
    );

    // Draw GPS altitude line
    _drawLine(
      canvas,
      size,
      history.map((r) => r.gpsAltitude).toList(),
      minAlt,
      range,
      secondaryColor,
    );
  }

  void _drawLine(
    Canvas canvas,
    Size size,
    List<double> data,
    double minValue,
    double range,
    Color color,
  ) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / math.max(1, data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedValue = (data[i] - minValue) / range;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(AltitudeHistoryPainter oldDelegate) {
    return oldDelegate.history != history;
  }
}
