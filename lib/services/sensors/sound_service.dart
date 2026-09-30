import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:fftea/fftea.dart';

/// Service for monitoring sound intensity (decibel) and pitch (frequency)
/// Singleton pattern ensures only one instance exists
class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  Timer? _recordingTimer;

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
    if (_listeners++ == 0) _start();
  }

  void _release() {
    if (--_listeners == 0) _stop();
  }

  Stream<double> get decibelStream => _decibelController.stream;
  Stream<PitchData> get pitchStream => _pitchController.stream;

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
        debugPrint('Audio recording permission not granted - requesting...');
        // Note: Permission will be requested automatically when starting recording
        // The app needs microphone permission in AndroidManifest.xml
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
      stream.listen(
        (data) {
          _processAudioData(data);
        },
        onError: (error) {
          debugPrint('Audio recording error: $error');
        },
      );

      // Monitor amplitude for decibel calculation.
      // A 1->0->1 flip inside the awaits above starts a second _start() body;
      // whichever gets here first owns the timer. Overwriting it would orphan a
      // Timer.periodic polling getAmplitude() that _stop() can never cancel.
      if (_recordingTimer != null) return;
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
        _,
      ) async {
        // A timer callback has no caller to catch for it, so catch here.
        try {
          final amplitude = await _recorder.getAmplitude();

          // amplitude.current is in dB (typically -160 to 0, where 0 is max)
          // Convert to standard SPL scale (0-120 dB)
          // -160 dB (silence) -> 0 dB SPL
          // 0 dB (max) -> 120 dB SPL
          // But we want to scale it more realistically:
          // Typical range: -40 dB to 0 dB -> 40 dB SPL to 120 dB SPL

          if (amplitude.current > -160) {
            // Map -40 dB to 0 dB -> 40 dB to 120 dB
            _decibelController.add(
              ((amplitude.current + 40) * 2).clamp(0, 120).toDouble(),
            );
          } else {
            // Complete silence
            _decibelController.add(0.0);
          }
        } catch (e) {
          debugPrint('Amplitude read failed: $e');
        }
      });
    } catch (e) {
      debugPrint('Error starting sound monitoring: $e');
    }
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
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _audioBuffer.clear();

    // `stop()` is what releases the microphone. The recorder itself is NOT
    // disposed: this singleton outlives every screen and retrySoundMonitoring()
    // reuses it, so tearing it down here would break the restart path.
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }
}

/// Pitch data class
class PitchData {
  final double frequency; // Hz
  final String noteName; // Musical note (e.g., "A4", "C#5")

  PitchData({required this.frequency, required this.noteName});
}
