import 'dart:math' as math;

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
              Text('Tools', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              _buildTools(context),
              const SizedBox(height: 20),
              Text('Live sensors', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              // Every card is wrapped in Builder so the ListView builds it lazily:
              // off-screen cards skip their build work on each 200 ms notify.

              // Battery Card (always expanded, no graph)
              Builder(
                builder: (context) => _buildBatteryCard(context, viewModel),
              ),
              const SizedBox(height: 12),

              // Magnetic Field Card
              if (viewModel.isSensorAvailable('magnetic')) ...[
                Builder(
                  builder: (context) => _buildSensorCard(
                    context,
                    viewModel,
                    sensorName: 'magnetic',
                    title: 'Magnetic Field',
                    icon: Icons.explore,
                    value: '${viewModel.magneticField.toStringAsFixed(1)} µT',
                    hasGraph: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Protected sensors start only when the user asks for them.
              if (!viewModel.isSensorAvailable('sound')) ...[
                Builder(
                  builder: (context) => _buildPermissionCard(
                    context,
                    title: 'Microphone level and pitch',
                    description: viewModel.soundStatus,
                    icon: Icons.mic_off,
                    actionLabel: 'Enable microphone',
                    onAction: viewModel.isRequestingSound
                        ? null
                        : () => viewModel.retrySoundMonitoring(),
                    onSettings: () => viewModel.openAppSettings(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Sound (Decibel) Card
              if (viewModel.isSensorAvailable('sound')) ...[
                Builder(
                  builder: (context) => _buildSensorCard(
                    context,
                    viewModel,
                    sensorName: 'decibel',
                    title: 'Microphone level',
                    icon: Icons.graphic_eq,
                    value:
                        '${viewModel.decibel.toStringAsFixed(1)} dBFS (signal level)',
                    hasGraph: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Pitch Card
              if (viewModel.isSensorAvailable('sound')) ...[
                Builder(
                  builder: (context) => _buildSensorCard(
                    context,
                    viewModel,
                    sensorName: 'pitch',
                    title: 'Pitch',
                    icon: Icons.music_note,
                    value:
                        '${viewModel.pitchNote} · ${viewModel.pitchFrequency.toStringAsFixed(1)} Hz',
                    hasGraph: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // GPS Card — shown even when permission denied so the user can
              // tap "Enable Location" inside the expanded card to retry.
              Builder(builder: (context) => _buildGPSCard(context, viewModel)),
              const SizedBox(height: 12),

              // Linear Acceleration Card
              if (viewModel.isSensorAvailable('accelerometer')) ...[
                Builder(
                  builder: (context) => _buildSensorCard(
                    context,
                    viewModel,
                    sensorName: 'accelerometer',
                    title: 'Acceleration',
                    icon: Icons.vibration,
                    value: viewModel.isCardExpanded('accelerometer')
                        ? 'X: ${viewModel.accelX.toStringAsFixed(2)}\n'
                              'Y: ${viewModel.accelY.toStringAsFixed(2)}\n'
                              'Z: ${viewModel.accelZ.toStringAsFixed(2)}\n'
                              'Mag: ${viewModel.accelMagnitude.toStringAsFixed(2)} m/s²'
                        : '${viewModel.accelMagnitude.toStringAsFixed(2)} m/s²',
                    hasGraph: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Orientation Card (with visual)
              if (viewModel.isSensorAvailable('orientation')) ...[
                Builder(
                  builder: (context) =>
                      _buildOrientationCard(context, viewModel),
                ),
                const SizedBox(height: 12),
              ],

              // Gyroscope Card
              if (viewModel.isSensorAvailable('gyroscope')) ...[
                Builder(
                  builder: (context) => _buildSensorCard(
                    context,
                    viewModel,
                    sensorName: 'gyroscope',
                    title: 'Gyroscope',
                    icon: Icons.rotate_right,
                    value: viewModel.isCardExpanded('gyroscope')
                        ? 'X: ${viewModel.gyroX.toStringAsFixed(3)}\n'
                              'Y: ${viewModel.gyroY.toStringAsFixed(3)}\n'
                              'Z: ${viewModel.gyroZ.toStringAsFixed(3)}\n'
                              'Mag: ${viewModel.gyroMagnitude.toStringAsFixed(3)} rad/s'
                        : '${viewModel.gyroMagnitude.toStringAsFixed(3)} rad/s',
                    hasGraph: true,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Proximity Card
              if (viewModel.isSensorAvailable('proximity')) ...[
                Builder(
                  builder: (context) => _buildProximityCard(context, viewModel),
                ),
                const SizedBox(height: 12),
              ],

              // Pressure Card
              if (viewModel.isSensorAvailable('pressure')) ...[
                Builder(
                  builder: (context) => _buildPressureCard(context, viewModel),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTools(BuildContext context) {
    const tools = [
      ('Spirit Level', Icons.architecture, '/spirit-level'),
      ('Magnetic Field', Icons.search, '/metal-detector'),
      ('Microphone Level', Icons.graphic_eq, '/decibel-meter'),
      ('Altitude Calculator', Icons.terrain, '/altitude-calculator'),
      ('Vibration Analyzer', Icons.vibration, '/vibration-analyzer'),
      ('Acceleration Meter', Icons.speed, '/g-force-meter'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 200).floor().clamp(2, 4);
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tools
              .map(
                (tool) => SizedBox(
                  width: width,
                  child: _buildToolCard(
                    context,
                    title: tool.$1,
                    icon: tool.$2,
                    onTap: () => Navigator.pushNamed(context, tool.$3),
                  ),
                ),
              )
              .toList(),
        );
      },
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
                        viewModel.isSensorAvailable('battery')
                            ? '${viewModel.batteryLevel}% - ${viewModel.batteryStatus}'
                            : 'Unavailable',
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
                    viewModel.isSensorAvailable('gps')
                        ? '${viewModel.latitude.toStringAsFixed(6)}°'
                        : '—',
                  ),
                  const SizedBox(height: 8),
                  _buildCoordinateRow(
                    context,
                    'Longitude',
                    viewModel.isSensorAvailable('gps')
                        ? '${viewModel.longitude.toStringAsFixed(6)}°'
                        : '—',
                  ),
                  const SizedBox(height: 8),
                  _buildCoordinateRow(
                    context,
                    'Altitude',
                    viewModel.isSensorAvailable('gps')
                        ? '${viewModel.altitude.toStringAsFixed(1)} m'
                        : '—',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: viewModel.isLoadingGPS
                            ? null
                            : viewModel.retryLocationPermission,
                        icon: const Icon(Icons.gps_fixed),
                        label: Text(
                          viewModel.hasLocationPermission
                              ? 'Retry location'
                              : 'Enable location',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: viewModel.openAppSettings,
                        icon: const Icon(Icons.settings),
                        label: const Text('App settings'),
                      ),
                      if (viewModel.gpsStatus == 'Location services OFF')
                        TextButton(
                          onPressed: viewModel.openLocationSettings,
                          child: const Text('Location settings'),
                        ),
                    ],
                  ),
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
                          'Pitch: ${(viewModel.pitch * 180 / math.pi).toStringAsFixed(1)}°\n'
                          'Roll: ${(viewModel.roll * 180 / math.pi).toStringAsFixed(1)}°',
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
    required VoidCallback? onAction,
    required VoidCallback onSettings,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Neutral colors: asking for a permission is not an error.
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
              child: Icon(icon, color: colorScheme.primary, size: 28),
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
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.mic, size: 18),
                    label: Text(actionLabel),
                  ),
                  TextButton(
                    onPressed: onSettings,
                    child: const Text('Open app settings'),
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
        // Digital microphone reference, with 0 as the maximum signal.
        safeMinY = -160;
        safeMaxY = 0;
        safeInterval = 40;
        break;
      case 'pitch':
        // Pitch: 0-4000 Hz (voice/music range).
        safeMinY = 0;
        safeMaxY = 4000;
        safeInterval = 1000;
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
    final radius = math.min(size.width / 3, size.height / 2 - 4);

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
    final bubbleX = (roll / (math.pi / 2)) * maxOffset;
    final bubbleY = (pitch / (math.pi / 2)) * maxOffset;

    // Clamp to circle
    final distance = math.sqrt(bubbleX * bubbleX + bubbleY * bubbleY);
    final clampedX = distance > maxOffset
        ? bubbleX * maxOffset / distance
        : bubbleX;
    final clampedY = distance > maxOffset
        ? bubbleY * maxOffset / distance
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
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
            ],
          ),
        ),
      ),
    ),
  );
}
