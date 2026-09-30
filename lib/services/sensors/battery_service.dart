import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:battery_plus/battery_plus.dart';

/// Service for monitoring battery information
/// Singleton pattern ensures only one instance exists
class BatteryService {
  static final BatteryService _instance = BatteryService._internal();
  factory BatteryService() => _instance;
  BatteryService._internal();

  final Battery _battery = Battery();
  // Controller owns the platform subscription — see AccelerometerService.
  late final _controller = StreamController<BatteryInfo>.broadcast(
    onListen: _start,
    onCancel: _stop,
  );
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  Stream<BatteryInfo> get stream => _controller.stream;

  Future<void> _start() async {
    // Push the current level right away, then track changes.
    await _updateBatteryInfo();

    // The last listener may have cancelled during that await; _stop() would
    // then have already run as a no-op, so don't start polling behind it. A
    // 1->0->1 flip in that same window starts a second _start() too: whichever
    // body gets here first owns _batteryStateSubscription, and the other bails
    // rather than overwriting a handle _stop() could never cancel.
    if (!_controller.hasListener || _batteryStateSubscription != null) return;

    _batteryStateSubscription = _battery.onBatteryStateChanged.listen(
      (_) => _updateBatteryInfo(),
      // Simulators have no battery: the plugin sends an UNAVAILABLE error event.
      onError: (Object e) => debugPrint('Battery state unavailable: $e'),
    );
  }

  void _stop() {
    _batteryStateSubscription?.cancel();
    _batteryStateSubscription = null;
  }

  /// Update battery information
  Future<void> _updateBatteryInfo() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;

      _controller.add(
        BatteryInfo(
          level: level,
          state: _batteryStateToString(state),
          isCharging: state == BatteryState.charging,
        ),
      );
    } catch (e) {
      debugPrint('Error getting battery info: $e');
    }
  }

  String _batteryStateToString(BatteryState state) {
    switch (state) {
      case BatteryState.full:
        return 'Full';
      case BatteryState.charging:
        return 'Charging';
      case BatteryState.discharging:
        return 'Discharging';
      case BatteryState.connectedNotCharging:
        return 'Not Charging';
      default:
        return 'Unknown';
    }
  }
}

/// Battery information data class
class BatteryInfo {
  final int level;
  final String state;
  final bool isCharging;

  BatteryInfo({
    required this.level,
    required this.state,
    required this.isCharging,
  });
}
