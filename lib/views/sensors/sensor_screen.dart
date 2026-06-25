import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../viewmodels/sensor_viewmodel.dart';

/// Sensor screen - displays all available sensors with expandable cards
/// Shows real-time sensor data and graphs
class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  late SensorViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SensorViewModel();
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: const _SensorScreenContent(),
    );
  }
}

class _SensorScreenContent extends StatelessWidget {
  const _SensorScreenContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sensors'), elevation: 0),
      body: Consumer<SensorViewModel>(
        builder: (context, viewModel, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Battery Card (always expanded, no graph)
              _buildBatteryCard(context, viewModel),
              const SizedBox(height: 12),

              // Light Sensor Card
              if (viewModel.isSensorAvailable('light')) ...[
                _buildSensorCard(
                  context,
                  viewModel,
                  sensorName: 'light',
                  title: 'Light Sensor',
                  icon: Icons.light_mode,
                  value: '${viewModel.lightLevel.toStringAsFixed(1)} lux',
                  hasGraph: true,
                ),
                const SizedBox(height: 12),
              ],

              // Magnetic Field Card
              if (viewModel.isSensorAvailable('magnetic')) ...[
                _buildSensorCard(
                  context,
                  viewModel,
                  sensorName: 'magnetic',
                  title: 'Magnetic Field',
                  icon: Icons.explore,
                  value: '${viewModel.magneticField.toStringAsFixed(1)} µT',
                  hasGraph: true,
                ),
                const SizedBox(height: 12),
              ],

              // Sound permission prompt (only when user has denied microphone)
              if (!viewModel.isSensorAvailable('sound') &&
                  viewModel.soundPermissionDenied) ...[
                _buildPermissionCard(
                  context,
                  title: 'Microphone access needed',
                  description:
                      'Enable microphone access to use Sound Level, Pitch detection, and the Decibel Meter.',
                  icon: Icons.mic_off,
                  actionLabel: 'Enable microphone',
                  onAction: () => viewModel.retrySoundMonitoring(),
                ),
                const SizedBox(height: 12),
              ],

              // Sound (Decibel) Card
              if (viewModel.isSensorAvailable('sound')) ...[
                _buildSensorCard(
                  context,
                  viewModel,
                  sensorName: 'decibel',
                  title: 'Sound Level',
                  icon: Icons.graphic_eq,
                  value: '${viewModel.decibel.toStringAsFixed(1)} dB',
                  hasGraph: true,
                ),
                const SizedBox(height: 12),
              ],

              // Pitch Card
              if (viewModel.isSensorAvailable('sound')) ...[
                _buildSensorCard(
                  context,
                  viewModel,
                  sensorName: 'pitch',
                  title: 'Pitch',
                  icon: Icons.music_note,
                  value:
                      '${viewModel.pitchFrequency.toStringAsFixed(1)} Hz\n${viewModel.pitchNote}',
                  hasGraph: true,
                ),
                const SizedBox(height: 12),
              ],

              // GPS Card — shown even when permission denied so the user can
              // tap "Enable Location" inside the expanded card to retry.
              _buildGPSCard(context, viewModel),
              const SizedBox(height: 12),

              // Linear Acceleration Card
              if (viewModel.isSensorAvailable('accelerometer')) ...[
                _buildSensorCard(
                  context,
                  viewModel,
                  sensorName: 'accelerometer',
                  title: 'Acceleration',
                  icon: Icons.vibration,
                  value:
                      'X: ${viewModel.accelX.toStringAsFixed(2)}\n'
                      'Y: ${viewModel.accelY.toStringAsFixed(2)}\n'
                      'Z: ${viewModel.accelZ.toStringAsFixed(2)}\n'
                      'Mag: ${viewModel.accelMagnitude.toStringAsFixed(2)} m/s²',
                  hasGraph: true,
                ),
                const SizedBox(height: 12),
              ],

              // Orientation Card (with visual)
              if (viewModel.isSensorAvailable('orientation')) ...[
                _buildOrientationCard(context, viewModel),
                const SizedBox(height: 12),
              ],

              // Gyroscope Card
              if (viewModel.isSensorAvailable('gyroscope')) ...[
                _buildSensorCard(
                  context,
                  viewModel,
                  sensorName: 'gyroscope',
                  title: 'Gyroscope',
                  icon: Icons.rotate_right,
                  value:
                      'X: ${viewModel.gyroX.toStringAsFixed(3)}\n'
                      'Y: ${viewModel.gyroY.toStringAsFixed(3)}\n'
                      'Z: ${viewModel.gyroZ.toStringAsFixed(3)}\n'
                      'Mag: ${viewModel.gyroMagnitude.toStringAsFixed(3)} rad/s',
                  hasGraph: true,
                ),
                const SizedBox(height: 12),
              ],

              // Proximity Card
              if (viewModel.isSensorAvailable('proximity')) ...[
                _buildProximityCard(context, viewModel),
                const SizedBox(height: 12),
              ],

              // Pressure Card
              if (viewModel.isSensorAvailable('pressure')) ...[
                _buildPressureCard(context, viewModel),
                const SizedBox(height: 12),
              ],

              // Tools Section
              const SizedBox(height: 24),
              Text(
                'Sensor Tools',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Spirit Level Tool (requires accelerometer)
              if (viewModel.isSensorAvailable('accelerometer')) ...[
                _buildToolCard(
                  context,
                  title: 'Spirit Level',
                  icon: Icons.architecture,
                  description:
                      '2D bubble level for hanging pictures and checking surfaces',
                  onTap: () => Navigator.pushNamed(context, '/spirit-level'),
                ),
                const SizedBox(height: 12),
              ],

              // Metal Detector Tool (requires magnetometer)
              if (viewModel.isSensorAvailable('magnetic')) ...[
                _buildToolCard(
                  context,
                  title: 'Metal Detector',
                  icon: Icons.search,
                  description: 'Find studs in walls and locate metal objects',
                  onTap: () => Navigator.pushNamed(context, '/metal-detector'),
                ),
                const SizedBox(height: 12),
              ],

              // Decibel Meter Tool (requires sound)
              if (viewModel.isSensorAvailable('sound')) ...[
                _buildToolCard(
                  context,
                  title: 'Decibel Meter',
                  icon: Icons.graphic_eq,
                  description: 'Measure sound levels with safety warnings',
                  onTap: () => Navigator.pushNamed(context, '/decibel-meter'),
                ),
                const SizedBox(height: 12),
              ],

              // Altitude Calculator Tool (requires pressure + GPS)
              if (viewModel.isSensorAvailable('pressure') &&
                  viewModel.isSensorAvailable('gps')) ...[
                _buildToolCard(
                  context,
                  title: 'Altitude Calculator',
                  icon: Icons.terrain,
                  description: 'Track elevation and predict weather changes',
                  onTap: () =>
                      Navigator.pushNamed(context, '/altitude-calculator'),
                ),
                const SizedBox(height: 12),
              ],

              // Vibration Analyzer Tool (requires accelerometer)
              if (viewModel.isSensorAvailable('accelerometer')) ...[
                _buildToolCard(
                  context,
                  title: 'Vibration Analyzer',
                  icon: Icons.vibration,
                  description: 'Analyze vibrations for diagnostics and safety',
                  onTap: () =>
                      Navigator.pushNamed(context, '/vibration-analyzer'),
                ),
                const SizedBox(height: 12),
              ],

              // Acceleration Meter Tool (requires accelerometer)
              if (viewModel.isSensorAvailable('accelerometer')) ...[
                _buildToolCard(
                  context,
                  title: 'Acceleration Meter',
                  icon: Icons.speed,
                  description: 'Measure vehicle acceleration and speed changes',
                  onTap: () => Navigator.pushNamed(context, '/g-force-meter'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Build battery card (always expanded)
  Widget _buildBatteryCard(BuildContext context, SensorViewModel viewModel) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    viewModel.isCharging
                        ? Icons.battery_charging_full
                        : Icons.battery_std,
                    color: colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Battery',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${viewModel.batteryLevel}% - ${viewModel.batteryStatus}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build generic sensor card with optional graph
  Widget _buildSensorCard(
    BuildContext context,
    SensorViewModel viewModel, {
    required String sensorName,
    required String title,
    required IconData icon,
    required String value,
    bool hasGraph = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isExpanded = viewModel.isCardExpanded(sensorName);

    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => viewModel.toggleCard(sensorName),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && hasGraph)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildLineChart(context, viewModel, sensorName),
            ),
        ],
      ),
    );
  }

  /// Build GPS card with special layout
  Widget _buildGPSCard(BuildContext context, SensorViewModel viewModel) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isExpanded = viewModel.isCardExpanded('gps');

    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => viewModel.toggleCard('gps'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.location_on,
                      color: colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GPS',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (viewModel.isLoadingGPS)
                          Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                viewModel.gpsStatus,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            viewModel.gpsStatus,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _buildCoordinateRow(
                    context,
                    'Latitude',
                    '${viewModel.latitude.toStringAsFixed(6)}°',
                  ),
                  const SizedBox(height: 8),
                  _buildCoordinateRow(
                    context,
                    'Longitude',
                    '${viewModel.longitude.toStringAsFixed(6)}°',
                  ),
                  const SizedBox(height: 8),
                  _buildCoordinateRow(
                    context,
                    'Altitude',
                    '${viewModel.altitude.toStringAsFixed(1)} m',
                  ),
                  if (!viewModel.hasLocationPermission) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => viewModel.retryLocationPermission(),
                            icon: const Icon(Icons.gps_fixed),
                            label: const Text('Grant permission'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => viewModel.openLocationSettings(),
                          icon: const Icon(Icons.settings),
                          label: const Text('Settings'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Build orientation card with visual display
  Widget _buildOrientationCard(
    BuildContext context,
    SensorViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isExpanded = viewModel.isCardExpanded('orientation');

    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () => viewModel.toggleCard('orientation'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.screen_rotation,
                      color: colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Orientation',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pitch: ${viewModel.pitch.toStringAsFixed(1)}°\n'
                          'Roll: ${viewModel.roll.toStringAsFixed(1)}°',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: OrientationVisualWidget(
                pitch: viewModel.pitch,
                roll: viewModel.roll,
              ),
            ),
        ],
      ),
    );
  }

  /// Build proximity card
  Widget _buildProximityCard(BuildContext context, SensorViewModel viewModel) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.sensors,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Proximity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    viewModel.isNear ? 'Near' : 'Far',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build pressure card
  Widget _buildPressureCard(BuildContext context, SensorViewModel viewModel) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.speed,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pressure',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${viewModel.pressure.toStringAsFixed(2)} hPa',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build coordinate row for GPS
  Widget _buildCoordinateRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Build a permission-denied / sensor-needs-action card.
  /// Shows an icon, a title + description, and a single action button.
  /// Used when a sensor is unavailable for a reason the user can fix
  /// (e.g. microphone permission denied).
  Widget _buildPermissionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.errorContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.error, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(actionLabel),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build line chart for sensor data with smooth animations
  Widget _buildLineChart(
    BuildContext context,
    SensorViewModel viewModel,
    String sensorName,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    List<double> data;
    switch (sensorName) {
      case 'light':
        data = viewModel.lightGraphData;
        break;
      case 'magnetic':
        data = viewModel.magneticGraphData;
        break;
      case 'decibel':
        data = viewModel.decibelGraphData;
        break;
      case 'pitch':
        data = viewModel.pitchGraphData;
        break;
      case 'gyroscope':
        data = viewModel.gyroscopeGraphData;
        break;
      case 'accelerometer':
        data = viewModel.accelerometerGraphData;
        break;
      default:
        data = [];
    }

    if (data.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Text(
            'Collecting data...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    // Convert data to FlSpot
    final spots = List.generate(
      data.length,
      (index) => FlSpot(index.toDouble(), data[index]),
    );

    // Calculate min/max for Y axis with smoothing
    // Use a wider range to avoid constant rescaling
    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);

    // Use fixed scale ranges based on sensor type to reduce jank
    double safeMinY, safeMaxY, safeInterval;

    switch (sensorName) {
      case 'decibel':
        // Decibels: 0-120 dB fixed scale
        safeMinY = 0;
        safeMaxY = 120;
        safeInterval = 30;
        break;
      case 'pitch':
        // Pitch: 0-2000 Hz (typical voice/music range)
        safeMinY = 0;
        safeMaxY = 2000;
        safeInterval = 500;
        break;
      default:
        // Dynamic scale for other sensors with extra padding
        final range = maxY - minY;
        if (range > 0) {
          final padding = range * 0.3; // More padding for stability
          safeMinY = minY - padding;
          safeMaxY = maxY + padding;
          safeInterval = range / 3;
        } else {
          // All values same
          safeMinY = minY - 1.0;
          safeMaxY = maxY + 1.0;
          safeInterval = 0.5;
        }
    }

    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: safeInterval,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: colorScheme.onSurface.withValues(alpha: 0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: spots.length.toDouble() - 1,
          minY: safeMinY,
          maxY: safeMaxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved:
                  false, // Straight lines are smoother than curved with fast updates
              color: colorScheme.primary,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
        // Add smooth animation
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
      ),
    );
  }
}

/// Orientation visual widget - shows pitch and roll as 2D bubble level
class OrientationVisualWidget extends StatelessWidget {
  final double pitch;
  final double roll;

  const OrientationVisualWidget({
    super.key,
    required this.pitch,
    required this.roll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 200,
      child: CustomPaint(
        painter: OrientationPainter(
          pitch: pitch,
          roll: roll,
          primaryColor: colorScheme.primary,
          surfaceColor: colorScheme.surface,
          onSurfaceColor: colorScheme.onSurface,
        ),
        child: Container(),
      ),
    );
  }
}

/// Custom painter for orientation visual
class OrientationPainter extends CustomPainter {
  final double pitch;
  final double roll;
  final Color primaryColor;
  final Color surfaceColor;
  final Color onSurfaceColor;

  OrientationPainter({
    required this.pitch,
    required this.roll,
    required this.primaryColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    // Draw outer circle (fixed)
    final outerPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
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

    // Calculate bubble position from pitch and roll
    // pitch affects Y, roll affects X
    final maxOffset = radius * 0.8;
    final bubbleX = (roll / 90) * maxOffset;
    final bubbleY = (pitch / 90) * maxOffset;

    // Clamp to circle
    final distance = (bubbleX * bubbleX + bubbleY * bubbleY).abs();
    final clampedX = distance > maxOffset * maxOffset
        ? bubbleX * maxOffset / distance.abs()
        : bubbleX;
    final clampedY = distance > maxOffset * maxOffset
        ? bubbleY * maxOffset / distance.abs()
        : bubbleY;

    final bubbleCenter = Offset(center.dx + clampedX, center.dy + clampedY);

    // Draw bubble with gradient
    final bubblePaint = Paint()..color = primaryColor.withValues(alpha: 0.3);
    canvas.drawCircle(bubbleCenter, 20, bubblePaint);

    final bubbleCorePaint = Paint()..color = primaryColor;
    canvas.drawCircle(bubbleCenter, 12, bubbleCorePaint);

    // Draw highlight
    final highlightPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(bubbleCenter.translate(-4, -4), 5, highlightPaint);

    // Draw center dot (ideal level position)
    final centerDotPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, centerDotPaint);
  }

  @override
  bool shouldRepaint(OrientationPainter oldDelegate) {
    return oldDelegate.pitch != pitch || oldDelegate.roll != roll;
  }
}

/// Build tool card for sensor-based utility tools
Widget _buildToolCard(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String description,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
              size: 16,
            ),
          ],
        ),
      ),
    ),
  );
}
