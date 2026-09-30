import 'package:aninitools/services/sensors/sound_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pitch names cross octave boundaries correctly', () {
    expect(SoundService.frequencyToNote(440), 'A4');
    expect(SoundService.frequencyToNote(261.63), 'C4');
    expect(SoundService.frequencyToNote(246.94), 'B3');
    expect(SoundService.frequencyToNote(880), 'A5');
  });
}
