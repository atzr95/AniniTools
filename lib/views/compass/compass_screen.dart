import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../../viewmodels/compass_viewmodel.dart';

/// Compass screen - shows magnetic north direction
/// Uses magnetometer + accelerometer for tilt-compensated orientation
class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> with SingleTickerProviderStateMixin {
  late CompassViewModel _viewModel;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _viewModel = CompassViewModel();
    _viewModel.initialize();

    // Pulse animation for GPS loading indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: _CompassView(pulseController: _pulseController),
    );
  }
}

class _CompassView extends StatelessWidget {
  final AnimationController pulseController;

  const _CompassView({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compass'),
        actions: [
          // Calibration button
          IconButton(
            icon: const Icon(Icons.settings_backup_restore),
            onPressed: () {
              context.read<CompassViewModel>().calibrate();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rotate device in figure-8 pattern to calibrate'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            tooltip: 'Calibrate Compass',
          ),
        ],
      ),
      body: Consumer<CompassViewModel>(
        builder: (context, viewModel, child) {
          if (!viewModel.hasLocationPermission) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Location Permission Required',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Enable location access to see GPS coordinates',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => viewModel.initialize(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Request Permission'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.read<CompassViewModel>().openAppSettings(),
                    icon: const Icon(Icons.settings),
                    label: const Text('Open App Settings'),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;
                // Dynamically size compass based on available space - made bigger
                final compassSize = (availableHeight * 0.45).clamp(240.0, 320.0);

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: availableHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // Heading display with smooth number transitions
                      TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: viewModel.heading),
                  duration: const Duration(milliseconds: 100),
                  builder: (context, value, child) {
                    return Text(
                      '${value.toStringAsFixed(0)}°',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        fontSize: 56,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 4),

                // Direction text
                Text(
                  viewModel.getDirectionText(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 2),

                // Full direction name
                Text(
                  viewModel.getFullDirectionName(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),

                const SizedBox(height: 20),

                // Compass circle with smooth rotation - dynamic size
                SizedBox(
                  width: compassSize,
                  height: compassSize,
                  child: CustomPaint(
                    painter: CompassPainter(
                      heading: viewModel.heading,
                      pitch: viewModel.pitch,
                      roll: viewModel.roll,
                      primaryColor: colorScheme.primary,
                      surfaceColor: colorScheme.surface,
                      onSurfaceColor: colorScheme.onSurface,
                    ),
                  ),
                ),

                const Spacer(),

                // GPS Coordinates - Compact
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // GPS Status + Turn On Location button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (viewModel.isLoadingGPS)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                              const SizedBox(width: 6),
                              Text(
                                viewModel.gpsStatus,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (viewModel.gpsStatus == 'Location services are OFF')
                            TextButton(
                              onPressed: () => context.read<CompassViewModel>().openLocationSettings(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Turn On',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Compact coordinate display
                      if (!viewModel.isLoadingGPS && viewModel.latitude != 0.0)
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildCompactCoordinate(
                                    context,
                                    'LAT',
                                    viewModel.latitude,
                                    '°',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCompactCoordinate(
                                    context,
                                    'LON',
                                    viewModel.longitude,
                                    '°',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCompactCoordinate(
                                    context,
                                    'ALT',
                                    viewModel.altitude,
                                    'm',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactCoordinate(
    BuildContext context,
    String label,
    double value,
    String suffix,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: value),
          duration: const Duration(milliseconds: 300),
          builder: (context, animatedValue, child) {
            final displayValue = suffix == 'm'
                ? animatedValue.toStringAsFixed(1)
                : animatedValue.toStringAsFixed(4);
            return Text(
              '$displayValue$suffix',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
      ],
    );
  }
}

/// Custom painter for compass needle and markings
class CompassPainter extends CustomPainter {
  final double heading;
  final double pitch;
  final double roll;
  final Color primaryColor;
  final Color surfaceColor;
  final Color onSurfaceColor;

  CompassPainter({
    required this.heading,
    required this.pitch,
    required this.roll,
    required this.primaryColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer circle
    final circlePaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 10, circlePaint);

    // Draw inner circle (subtle)
    final innerCirclePaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius - 25, innerCirclePaint);

    // Rotate the entire compass rose so North points to the correct direction
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-heading * math.pi / 180);

    // Draw cardinal direction markers (will rotate with compass rose)
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final directions = ['N', 'E', 'S', 'W'];
    final directionColors = [primaryColor, onSurfaceColor, onSurfaceColor, onSurfaceColor];

    for (int i = 0; i < 4; i++) {
      final angle = (i * 90) * math.pi / 180;
      final x = (radius - 35) * math.sin(angle);
      final y = -(radius - 35) * math.cos(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(heading * math.pi / 180); // Counter-rotate text to keep it upright

      textPainter.text = TextSpan(
        text: directions[i],
        style: TextStyle(
          color: directionColors[i],
          fontSize: directions[i] == 'N' ? 32 : 26,
          fontWeight: directions[i] == 'N' ? FontWeight.w900 : FontWeight.bold,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    // Draw degree markers (every 30 degrees)
    for (int i = 0; i < 360; i += 30) {
      final angle = i * math.pi / 180;
      final isCardinal = i % 90 == 0;
      final x1 = (radius - (isCardinal ? 55 : 50)) * math.sin(angle);
      final y1 = -(radius - (isCardinal ? 55 : 50)) * math.cos(angle);
      final x2 = (radius - (isCardinal ? 45 : 40)) * math.sin(angle);
      final y2 = -(radius - (isCardinal ? 45 : 40)) * math.cos(angle);

      final markerPaint = Paint()
        ..color = onSurfaceColor.withValues(alpha: isCardinal ? 0.4 : 0.2)
        ..strokeWidth = isCardinal ? 2 : 1.5;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), markerPaint);
    }

    canvas.restore();

    // Draw fixed direction indicator at top (doesn't rotate - shows your heading direction)
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Fixed red arrow pointing up (your heading direction)
    final indicatorPath = Path()
      ..moveTo(0, -radius + 55)
      ..lineTo(-12, -radius + 75)
      ..lineTo(0, -radius + 68)
      ..lineTo(12, -radius + 75)
      ..close();

    final indicatorPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    canvas.drawPath(indicatorPath, indicatorPaint);

    // Outline for visibility
    final indicatorOutlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(indicatorPath, indicatorOutlinePaint);

    // 3D Gyroscope effect in center (shows phone tilt)
    // Calculate bubble offset based on pitch and roll
    // When phone is flat: pitch ≈ 0, roll ≈ 0
    // When tilted: bubble moves to show tilt direction
    final maxOffset = 8.0; // Maximum bubble displacement
    final bubbleX = roll * maxOffset * 2; // roll affects X movement
    final bubbleY = pitch * maxOffset * 2; // pitch affects Y movement

    // Clamp bubble movement to stay within outer ring
    final bubbleDistance = math.sqrt(bubbleX * bubbleX + bubbleY * bubbleY);
    final clampedBubbleX = bubbleDistance > maxOffset
        ? bubbleX * maxOffset / bubbleDistance
        : bubbleX;
    final clampedBubbleY = bubbleDistance > maxOffset
        ? bubbleY * maxOffset / bubbleDistance
        : bubbleY;

    // Draw outer ring (fixed)
    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, 12, ringPaint);

    // Draw inner background circle
    final bgPaint = Paint()..color = primaryColor.withValues(alpha: 0.1);
    canvas.drawCircle(Offset.zero, 12, bgPaint);

    // Draw moving bubble (3D sphere effect)
    final bubbleCenter = Offset(clampedBubbleX, clampedBubbleY);

    // Outer bubble glow
    final glowPaint = Paint()..color = primaryColor.withValues(alpha: 0.3);
    canvas.drawCircle(bubbleCenter, 8, glowPaint);

    // Main bubble
    final bubblePaint = Paint()..color = primaryColor;
    canvas.drawCircle(bubbleCenter, 6, bubblePaint);

    // Highlight (makes it look 3D)
    final highlightPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(bubbleCenter.translate(-2, -2), 2.5, highlightPaint);

    // Center dot (shows ideal flat position)
    final centerDotPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 2, centerDotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(CompassPainter oldDelegate) {
    return oldDelegate.heading != heading ||
           oldDelegate.pitch != pitch ||
           oldDelegate.roll != roll;
  }
}
