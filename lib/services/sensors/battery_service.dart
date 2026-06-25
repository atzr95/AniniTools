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
  StreamController<BatteryInfo> _controller =
      StreamController<BatteryInfo>.broadcast();
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  Stream<BatteryInfo> get stream {
    if (_controller.isClosed) {
      _controller = StreamController<BatteryInfo>.broadcast();
    }
    return _controller.stream;
  }

  BatteryInfo? _currentInfo;

  /// Start listening to battery changes
  Future<void> startListening() async {
    // Ensure clean state if restarted
    await stopListening();
    if (_controller.isClosed) {
      _controller = StreamController<BatteryInfo>.broadcast();
    }

    // Get initial state
    await _updateBatteryInfo();

    // Listen for battery state changes
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen((_) async {
      await _updateBatteryInfo();
    });
  }

  /// Stop listening to battery state changes. Safe to call repeatedly.
  Future<void> stopListening() async {
    await _batteryStateSubscription?.cancel();
    _batteryStateSubscription = null;
  }

  /// Update battery information
  Future<void> _updateBatteryInfo() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;

      _currentInfo = BatteryInfo(
        level: level,
        state: _batteryStateToString(state),
        isCharging: state == BatteryState.charging,
      );

      _controller.add(_currentInfo!);
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

  /// Get current battery info
  Future<BatteryInfo> getCurrentInfo() async {
    await _updateBatteryInfo();
    return _currentInfo!;
  }

  /// Stop listening and cleanup
  Future<void> dispose() async {
    await stopListening();
    if (!_controller.isClosed) {
      await _controller.close();
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
