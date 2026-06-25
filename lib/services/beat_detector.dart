import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Result of attempting to start a [BeatDetector].
enum BeatDetectorStartResult {
  /// Audio capture started and beat detection is running.
  success,

  /// The user denied microphone permission. Caller should show UI.
  permissionDenied,

  /// Platform/audio subsystem failed to start. Caller should show UI.
  error,
}

/// Live audio-to-beat analyser used by Concert Mode.
///
/// Owns an [AudioRecorder] and consumes the raw PCM stream to emit two
/// kinds of signals:
///
/// - [onBeat]: fired on each detected onset (spectral flux above threshold).
/// - [onSustainChange]: fired with `true` when the sound becomes loud enough
///   to hold a light on, and `false` after several quiet chunks. This is the
///   hook used by Concert Mode to turn the torch on/off in sync with music.
///
/// The detector is decoupled from any particular output device — it does not
/// know about torches or screens. Callers wire the callbacks to whatever
/// effect they want. This keeps the detection logic reusable and unit
/// testable in isolation from the UI.
///
/// Tuning knobs: [sensitivity] (0.0–1.0) scales both the absolute energy gate
/// and the relative onset multiplier — higher values let quieter sounds
/// through. [minimumBeatIntervalMs] enforces a minimum gap between onsets so
/// faster strobe-rate settings correspond to tighter beat windows.
class BeatDetector {
  BeatDetector({
    this.sensitivity = 0.5,
    this.minimumBeatIntervalMs = 500,
    this.onBeat,
    this.onSustainChange,
  });

  /// 0.0 (only very loud peaks trigger) → 1.0 (very sensitive).
  double sensitivity;

  /// Minimum time between [onBeat] events. Keeps detection from firing
  /// faster than the configured strobe frequency.
  int minimumBeatIntervalMs;

  VoidCallback? onBeat;
  void Function(bool sustainOn)? onSustainChange;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _subscription;
  bool _running = false;
  bool _sustainOn = false;

  // Rolling-window beat detection state
  DateTime _lastBeatTime = DateTime.now();
  double _previousEnergy = 0.0;
  final List<double> _energyHistory = [];
  static const int _historySize = 43; // ~1 s at 44.1 kHz with default chunks
  double _averageEnergy = 0.0;

  // Hysteresis counters for the sustain signal
  int _consecutiveHighEnergyChunks = 0;
  int _consecutiveLowEnergyChunks = 0;

  bool get isRunning => _running;

  /// Request mic permission and begin streaming audio.
  /// Returns a [BeatDetectorStartResult] so callers can distinguish the
  /// "user said no" case from a platform failure.
  Future<BeatDetectorStartResult> start() async {
    if (_running) return BeatDetectorStartResult.success;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      return BeatDetectorStartResult.permissionDenied;
    }

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ),
      );
      _running = true;
      _subscription = stream.listen(
        _handleAudioChunk,
        onError: (Object e) {
          debugPrint('BeatDetector audio stream error: $e');
        },
      );
      return BeatDetectorStartResult.success;
    } catch (e) {
      debugPrint('BeatDetector failed to start: $e');
      return BeatDetectorStartResult.error;
    }
  }

  void _handleAudioChunk(Uint8List data) {
    if (!_running) return;

    final energy = _calculateEnergy(data);
    final minThreshold = 0.05 * (1.0 - sensitivity * 0.7);
    final isLoudEnough = energy > minThreshold;

    if (isLoudEnough) {
      _consecutiveHighEnergyChunks++;
      _consecutiveLowEnergyChunks = 0;
    } else {
      _consecutiveLowEnergyChunks++;
      _consecutiveHighEnergyChunks = 0;
    }

    if (_detectBeatOnset(energy)) {
      onBeat?.call();
    }

    // Hysteresis: turn ON after 1 high chunk, OFF after 3 low chunks.
    if (_consecutiveHighEnergyChunks >= 1 && !_sustainOn) {
      _sustainOn = true;
      onSustainChange?.call(true);
    } else if (_consecutiveLowEnergyChunks >= 3 && _sustainOn) {
      _sustainOn = false;
      onSustainChange?.call(false);
    }
  }

  /// Instantaneous energy of a PCM16 chunk. Processes every 4th byte pair
  /// for faster response (the original code chose this tradeoff after
  /// tuning; keeping it identical preserves user-visible behaviour).
  double _calculateEnergy(Uint8List data) {
    if (data.isEmpty) return 0.0;
    double energy = 0.0;
    for (int i = 0; i < data.length - 1; i += 4) {
      final sample = (data[i + 1] << 8) | data[i];
      final amplitude = sample > 32767 ? sample - 65536 : sample;
      final normalized = amplitude / 32768.0;
      energy += normalized * normalized;
    }
    return energy / (data.length / 4);
  }

  bool _detectBeatOnset(double currentEnergy) {
    final now = DateTime.now();
    final sinceLast = now.difference(_lastBeatTime).inMilliseconds;

    _energyHistory.add(currentEnergy);
    if (_energyHistory.length > _historySize) {
      _energyHistory.removeAt(0);
    }
    if (_energyHistory.length < 10) {
      _previousEnergy = currentEnergy;
      return false;
    }

    double sum = 0.0;
    for (int i = 0; i < _energyHistory.length - 1; i++) {
      sum += _energyHistory[i];
    }
    _averageEnergy = sum / (_energyHistory.length - 1);

    // Absolute minimum energy — prevents ambient noise from triggering.
    final minEnergyThreshold = 0.05 * (1.0 - sensitivity * 0.7);
    if (currentEnergy < minEnergyThreshold) {
      _previousEnergy = currentEnergy;
      return false;
    }

    final multiplier = 1.3 + (1.2 * (1.0 - sensitivity));
    final energyThreshold = _averageEnergy * multiplier;
    final flux = currentEnergy - _previousEnergy;
    final fluxThreshold = _averageEnergy * 0.4 * (1.0 - sensitivity * 0.6);

    bool isBeat = false;
    if (currentEnergy > energyThreshold &&
        flux > fluxThreshold &&
        sinceLast > minimumBeatIntervalMs) {
      _lastBeatTime = now;
      isBeat = true;
    }
    _previousEnergy = currentEnergy;
    return isBeat;
  }

  /// Stop streaming audio. Safe to call when not running. Idempotent.
  Future<void> stop() async {
    _running = false;
    await _subscription?.cancel();
    _subscription = null;

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      debugPrint('BeatDetector.stop recorder error: $e');
    }

    _energyHistory.clear();
    _previousEnergy = 0.0;
    _averageEnergy = 0.0;
    _consecutiveHighEnergyChunks = 0;
    _consecutiveLowEnergyChunks = 0;

    if (_sustainOn) {
      _sustainOn = false;
      onSustainChange?.call(false);
    }
  }

  /// Stop and release the underlying AudioRecorder's native resources.
  /// After this, the detector cannot be restarted.
  Future<void> dispose() async {
    await stop();
    try {
      await _recorder.dispose();
    } catch (e) {
      debugPrint('BeatDetector recorder dispose error: $e');
    }
  }
}
