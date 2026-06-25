import 'package:flutter/material.dart';

/// A compact card showing a single measurement: an icon, a label, and a value.
///
/// Shared by the tool screens (decibel meter, vibration analyzer, metal
/// detector, altitude calculator) which each had a private clone of this.
class MeasurementCard extends StatelessWidget {
  const MeasurementCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.unit,
    this.color,
    this.subtitle,
  });

  /// Caption shown above the value (e.g. 'Peak', 'Average').
  final String label;

  /// The measurement itself (e.g. '72.4').
  final String value;

  /// Icon shown at the top of the card.
  final IconData icon;

  /// Optional unit appended after the value (e.g. 'dB', 'm').
  final String? unit;

  /// Optional override for the icon tint. Defaults to colorScheme.primary.
  final Color? color;

  /// Optional small text shown below the value.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color ?? colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              unit == null ? value : '$value $unit',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
