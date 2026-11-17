import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/sensor_viewmodel.dart';
import '../../widgets/measurement_card.dart';
import '../../utils/capped_list.dart';

/// Shows the recorder's digital level. Physical sound pressure needs calibration.
class DecibelMeterScreen extends StatefulWidget {
  const DecibelMeterScreen({super.key});
  @override
  State<DecibelMeterScreen> createState() => _DecibelMeterScreenState();
}

class _DecibelMeterScreenState extends State<DecibelMeterScreen> {
  SensorViewModel? _model;
  int _lastSample = 0, _sampleCount = 0;
  double _averageDb = 0;
  final List<double> _history = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model != null) return;
    _model = context.read<SensorViewModel>();
    _model!.addListener(_recordReading);
    _recordReading();
  }

  void _recordReading() {
    final model = _model!;
    final version = model.sampleVersion('sound');
    if (!model.isSensorAvailable('sound') || version == _lastSample) return;
    _lastSample = version;
    setState(() {
      _sampleCount++;
      _averageDb += (model.decibel - _averageDb) / _sampleCount;
      _history.pushCapped(model.decibel, 100);
    });
  }

  @override
  void dispose() {
    _model?.removeListener(_recordReading);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Microphone Level'),
        actions: [
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _history.clear();
                _sampleCount = 0;
                _averageDb = 0;
              });
            },
          ),
        ],
      ),
      body: Consumer<SensorViewModel>(
        builder: (context, model, _) {
          if (!model.isSensorAvailable('sound')) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(model.soundStatus, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: model.isRequestingSound
                          ? null
                          : model.retrySoundMonitoring,
                      icon: const Icon(Icons.mic),
                      label: const Text('Enable microphone'),
                    ),
                    TextButton(
                      onPressed: model.openAppSettings,
                      child: const Text('Open app settings'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: 280,
                child: CustomPaint(
                  painter: DecibelMeterPainter(
                    decibels: model.decibel,
                    primaryColor: colors.primary,
                    onSurfaceColor: colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'dBFS is the microphone signal level. 0 is its maximum.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Uncalibrated for sound pressure. Do not use this reading to judge hearing safety.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MeasurementCard(
                      label: 'Average',
                      value: _sampleCount == 0
                          ? '—'
                          : _averageDb.toStringAsFixed(1),
                      unit: 'dBFS',
                      icon: Icons.trending_flat,
                    ),
                  ),
                  Expanded(
                    child: MeasurementCard(
                      label: 'Recent peak',
                      value: _history.isEmpty
                          ? '—'
                          : _history.reduce(math.max).toStringAsFixed(1),
                      unit: 'dBFS',
                      icon: Icons.arrow_upward,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_history.isNotEmpty) ...[
                Text('Microphone history', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: CustomPaint(
                    painter: DecibelHistoryPainter(
                      data: _history,
                      primaryColor: colors.primary,
                      onSurfaceColor: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class DecibelMeterPainter extends CustomPainter {
  final double decibels;
  final Color primaryColor, onSurfaceColor;
  DecibelMeterPainter({
    required this.decibels,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 28;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    paint.color = onSurfaceColor.withValues(alpha: 0.1);
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(bounds, math.pi * .75, math.pi * 1.5, false, paint);
    paint.color = primaryColor;
    final fraction = ((decibels + 160) / 160).clamp(0.0, 1.0);
    if (fraction > 0) {
      canvas.drawArc(
        bounds,
        math.pi * .75,
        math.pi * 1.5 * fraction,
        false,
        paint,
      );
    }
    final text = TextPainter(
      text: TextSpan(
        text: '${decibels.toStringAsFixed(1)}\ndBFS',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: onSurfaceColor,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(DecibelMeterPainter old) =>
      old.decibels != decibels ||
      old.primaryColor != primaryColor ||
      old.onSurfaceColor != onSurfaceColor;
}

class DecibelHistoryPainter extends CustomPainter {
  final List<double> data;
  final Color primaryColor, onSurfaceColor;
  DecibelHistoryPainter({
    required this.data,
    required this.primaryColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i * size.width / math.max(1, data.length - 1);
      final y = size.height * (1 - ((data[i] + 160) / 160).clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  // The history is edited in place; the old painter sees that same list.
  @override
  bool shouldRepaint(DecibelHistoryPainter old) => true;
}
