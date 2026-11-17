import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:fftea/fftea.dart';

/// Digital microphone level (dBFS) and pitch. No sound-pressure calibration.
/// Singleton pattern ensures only one instance exists
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordingTimer;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<RecordState>? _stateSubscription;
  bool _paused = false;
  Future<void>? _starting;
  int _amplitudeFailures = 0;
  static const _maxAmplitudeFailures = 5; // 0.5 s of failed 100 ms polls

  // Controllers own the microphone — see AccelerometerService. Both share it,
  // so they share one count: per-controller onListen would double-start.
  int _listeners = 0;
  late final _decibelController = StreamController<double>.broadcast(
    onListen: _retain,
    onCancel: _release,
  );
  late final _pitchController = StreamController<PitchData>.broadcast(
    onListen: _retain,
    onCancel: _release,
  );

  void _retain() {
    if (_listeners++ == 0) startMonitoring();
  }

  void _release() {
    if (--_listeners == 0) _stop();
  }

  Stream<double> get decibelStream => _decibelController.stream;
  Stream<PitchData> get pitchStream => _pitchController.stream;

  /// Retry the shared recorder without dropping another screen's listeners.
  Future<void> startMonitoring() {
    if (_recordingTimer != null) {
      // A new listener during an interruption gets no samples; tell it why.
      if (_paused) _reportPaused();
      return Future<void>.value();
    }
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  final List<double> _audioBuffer = [];
  static const int _sampleRate = 44100;
  static const int _bufferSize =
      2048; // Reduced from 4096 for faster response (~46ms)

  /// Check if audio recording permission is granted
  Future<bool> _hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Explicitly request microphone permission. Returns true if granted.
  /// Uses the recorder's `hasPermission()` which on both iOS and Android
  /// triggers the system permission prompt if status is undetermined.
  Future<bool> requestPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Microphone permission request failed: $e');
      return false;
    }
  }

  /// Start listening to audio for decibel and pitch analysis
  Future<void> _start() async {
    try {
      // A rapid re-subscribe can race the fire-and-forget _stop() above it.
      await _stop();

      // Request permission if not granted
      if (!await _hasPermission()) {
        throw StateError('Microphone permission denied');
      }

      // The last listener may have cancelled during the awaits above; _stop()
      // would then have already run as a no-op. Opening the mic now would
      // leave it open for the rest of the process.
      if (_listeners == 0) return;

      // Start recording to stream
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
          audioInterruption: AudioInterruptionMode.pauseResume,
        ),
      );

      // Same race, now with the mic actually open — hand it straight back.
      if (_listeners == 0) {
        await _stop();
        return;
      }

      // Initialize pitch data immediately to show UI is ready
      _pitchController.add(PitchData(frequency: 0.0, noteName: '--'));

      // Process audio data for pitch detection
      _audioSubscription = stream.listen(
        (data) {
          if (!_paused) _processAudioData(data);
        },
        onError: (error) {
          debugPrint('Audio recording error: $error');
          _reportError(error);
        },
      );

      _paused = false;
      _amplitudeFailures = 0;
      _stateSubscription = _recorder.onStateChanged().listen((state) {
        _paused = state == RecordState.pause;
        if (_paused) {
          _audioBuffer.clear();
          _reportPaused();
        } else if (state == RecordState.stop) {
          _reportError(StateError('Microphone stopped'));
        }
      }, onError: _reportError);

      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
        _,
      ) async {
        // A timer callback has no caller to catch for it, so catch here.
        try {
          final amplitude = await _recorder.getAmplitude();
          _amplitudeFailures = 0;
          if (_paused) return;

          // Keep the recorder's digital reference; an offset cannot calibrate a microphone.
          _decibelController.add(amplitude.current.clamp(-160, 0).toDouble());
        } catch (e) {
          debugPrint('Amplitude read failed: $e');
          // One failed poll can be a hiccup; stop the shared mic only if it keeps failing.
          if (++_amplitudeFailures >= _maxAmplitudeFailures) _reportError(e);
        }
      });
    } catch (e) {
      debugPrint('Error starting sound monitoring: $e');
      _reportError(e);
    }
  }

  void _reportPaused() {
    final error = StateError('Microphone interrupted; waiting to resume');
    _decibelController.addError(error);
    _pitchController.addError(error);
  }

  void _reportError(Object error) {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _decibelController.addError(error);
    _pitchController.addError(error);
    _stop();
  }

  /// Process audio data for pitch detection using FFT
  void _processAudioData(Uint8List data) {
    // Convert bytes to doubles
    final samples = <double>[];
    for (int i = 0; i < data.length - 1; i += 2) {
      // Convert 16-bit PCM to double (-1.0 to 1.0)
      final sample = (data[i] | (data[i + 1] << 8)).toSigned(16) / 32768.0;
      samples.add(sample);
    }

    _audioBuffer.addAll(samples);

    // When buffer is full enough, perform FFT
    if (_audioBuffer.length >= _bufferSize) {
      _performFFT();
      // Clear buffer completely for faster updates instead of keeping overlap
      _audioBuffer.clear();
    }
  }

  /// Perform FFT and detect pitch
  void _performFFT() {
    try {
      // Apply Hann window to reduce spectral leakage
      final windowed = List<double>.generate(_bufferSize, (i) {
        final hannWindow = 0.5 * (1 - math.cos(2 * math.pi * i / _bufferSize));
        return _audioBuffer[i] * hannWindow;
      });

      // Perform FFT
      final fft = FFT(_bufferSize);
      final freq = fft.realFft(windowed);

      // Find peak frequency (pitch)
      // Focus on human voice/music range (80 Hz - 4000 Hz)
      double maxMagnitude = 0;
      int maxIndex = 0;

      // Calculate frequency range to search
      final minFreqBin = (80 * _bufferSize / _sampleRate).floor();
      final maxFreqBin = (4000 * _bufferSize / _sampleRate).ceil();

      for (int i = minFreqBin; i < maxFreqBin && i < freq.length ~/ 2; i++) {
        // Calculate magnitude from complex number (real and imaginary parts)
        final real = freq[i].x;
        final imag = freq[i].y;
        final magnitude = math.sqrt(real * real + imag * imag);
        if (magnitude > maxMagnitude) {
          maxMagnitude = magnitude;
          maxIndex = i;
        }
      }

      // Convert bin index to frequency in Hz
      final frequency = maxIndex * _sampleRate / _bufferSize;

      // Report pitch continuously with very low threshold for instant response
      // Threshold of 5 provides better real-time responsiveness
      final detected = maxMagnitude > 5 && frequency >= 80 && frequency <= 4000;
      _pitchController.add(
        PitchData(
          frequency: detected ? frequency : 0.0,
          noteName: detected ? frequencyToNote(frequency) : '--',
        ),
      );
    } catch (e) {
      debugPrint('FFT error: $e');
    }
  }

  /// Convert frequency to musical note name
  static String frequencyToNote(double frequency) {
    const noteNames = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];

    // Calculate number of half steps from A4 (440 Hz)
    final halfSteps = 12 * (math.log(frequency / 440) / math.log(2));
    final noteIndex =
        (halfSteps.round() + 9) % 12; // +9 because A is at index 9
    final octave = ((halfSteps.round() + 9) / 12).floor() + 4;

    return '${noteNames[noteIndex]}$octave';
  }

  /// Stop listening to audio
  Future<void> _stop() async {
    _paused = true;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _audioBuffer.clear();
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    // `stop()` is what releases the microphone. The recorder itself is NOT
    // disposed: this singleton outlives every screen and retrySoundMonitoring()
    // reuses it, so tearing it down here would break the restart path.
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (e) {
      debugPrint('Error stopping sound monitoring: $e');
    }
  }
}

/// Pitch data class
class PitchData {
  final double frequency; // Hz
  final String noteName; // Musical note (e.g., "A4", "C#5")

  PitchData({required this.frequency, required this.noteName});
}
