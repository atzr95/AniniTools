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
  StreamSubscription? _amplitudeSubscription;
  Timer? _recordingTimer;

  final _decibelController = StreamController<double>.broadcast();
  final _pitchController = StreamController<PitchData>.broadcast();

  Stream<double> get decibelStream => _decibelController.stream;
  Stream<PitchData> get pitchStream => _pitchController.stream;

  double? _currentDecibel;
  PitchData? _currentPitch;

  final List<double> _audioBuffer = [];
  static const int _sampleRate = 44100;
  static const int _bufferSize = 2048; // Reduced from 4096 for faster response (~46ms)

  /// Check if audio recording permission is granted
  Future<bool> hasPermission() async {
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
  Future<void> startListening() async {
    // Stop any existing recording first
    await stopListening();

    try {
      // Request permission if not granted
      if (!await hasPermission()) {
        debugPrint('Audio recording permission not granted - requesting...');
        // Note: Permission will be requested automatically when starting recording
        // The app needs microphone permission in AndroidManifest.xml
      }

      // Start recording to stream
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      // Initialize pitch data immediately to show UI is ready
      _currentPitch = PitchData(
        frequency: 0.0,
        noteName: '--',
        magnitude: 0.0,
      );
      _pitchController.add(_currentPitch!);

      // Process audio data for pitch detection
      stream.listen(
        (data) {
          _processAudioData(data);
        },
        onError: (error) {
          debugPrint('Audio recording error: $error');
        },
      );

      // Monitor amplitude for decibel calculation
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (
        _,
      ) async {
        final amplitude = await _recorder.getAmplitude();

        // amplitude.current is in dB (typically -160 to 0, where 0 is max)
        // Convert to standard SPL scale (0-120 dB)
        // -160 dB (silence) -> 0 dB SPL
        // 0 dB (max) -> 120 dB SPL
        // But we want to scale it more realistically:
        // Typical range: -40 dB to 0 dB -> 40 dB SPL to 120 dB SPL

        if (amplitude.current > -160) {
          // Map -40 dB to 0 dB -> 40 dB to 120 dB
          final db = ((amplitude.current + 40) * 2).clamp(0, 120).toDouble();
          _currentDecibel = db;
          _decibelController.add(_currentDecibel!);
        } else {
          // Complete silence
          _currentDecibel = 0.0;
          _decibelController.add(0.0);
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
      if (maxMagnitude > 5 && frequency >= 80 && frequency <= 4000) {
        final noteName = _frequencyToNote(frequency);
        _currentPitch = PitchData(
          frequency: frequency,
          noteName: noteName,
          magnitude: maxMagnitude,
        );
      } else {
        // No clear pitch detected - report silence
        _currentPitch = PitchData(
          frequency: 0.0,
          noteName: '--',
          magnitude: maxMagnitude,
        );
      }
      _pitchController.add(_currentPitch!);
    } catch (e) {
      debugPrint('FFT error: $e');
    }
  }

  /// Convert frequency to musical note name
  String _frequencyToNote(double frequency) {
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
    final octave =
        ((halfSteps + 48) ~/ 12) + 4; // +48 to handle negative values

    return '${noteNames[noteIndex]}$octave';
  }

  /// Stop listening to audio
  Future<void> stopListening() async {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _audioBuffer.clear();

    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  /// Cleanup
  void dispose() {
    stopListening();
    _decibelController.close();
    _pitchController.close();
    _recorder.dispose();
  }
}

/// Pitch data class
class PitchData {
  final double frequency; // Hz
  final String noteName; // Musical note (e.g., "A4", "C#5")
  final double magnitude; // FFT magnitude

  PitchData({
    required this.frequency,
    required this.noteName,
    required this.magnitude,
  });
}
