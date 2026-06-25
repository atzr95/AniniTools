import 'dart:async';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:torch_light/torch_light.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aninitools/widgets/painters/color_picker_painters.dart';
import 'concert_mode_screen.dart';

/// Global flashlight state tracker to persist across navigation
class _FlashlightState {
  static final _FlashlightState _instance = _FlashlightState._internal();
  factory _FlashlightState() => _instance;
  _FlashlightState._internal();

  bool isOn = false;
  FlashlightMode mode = FlashlightMode.normal;
  double brightness = 1.0;
  double strobeFrequency = 5.0;
  Color screenLightColor = Colors.white;
  int? autoOffMinutes;
  DateTime? autoOffStartTime;
  Timer? strobeTimer;
  Timer? autoOffTimer;
  bool sosActive = false;
}

/// Flashlight screen - main utility feature
/// Design: Clean, focused UI with large flashlight button
class FlashlightScreen extends StatefulWidget {
  const FlashlightScreen({super.key});

  @override
  State<FlashlightScreen> createState() => _FlashlightScreenState();
}

class _FlashlightScreenState extends State<FlashlightScreen> {
  final _FlashlightState _globalState = _FlashlightState();

  bool _isTorchAvailable = true;
  int _batteryLevel = 100;
  final Battery _battery = Battery();
  double? _originalBrightness;

  // UI state
  bool _showAdvancedOptions = false;

  // Custom SOS message (runtime only, not persisted)
  String _customSOSMessage = 'SOS';

  // Getters to access global state
  bool get _isFlashlightOn => _globalState.isOn;
  set _isFlashlightOn(bool value) => _globalState.isOn = value;

  FlashlightMode get _currentMode => _globalState.mode;
  set _currentMode(FlashlightMode value) => _globalState.mode = value;

  double get _brightness => _globalState.brightness;
  set _brightness(double value) => _globalState.brightness = value;

  double get _strobeFrequency => _globalState.strobeFrequency;
  set _strobeFrequency(double value) => _globalState.strobeFrequency = value;

  int? get _autoOffMinutes => _globalState.autoOffMinutes;
  set _autoOffMinutes(int? value) => _globalState.autoOffMinutes = value;

  DateTime? get _autoOffStartTime => _globalState.autoOffStartTime;
  set _autoOffStartTime(DateTime? value) =>
      _globalState.autoOffStartTime = value;

  Timer? get _strobeTimer => _globalState.strobeTimer;
  set _strobeTimer(Timer? value) => _globalState.strobeTimer = value;

  Timer? get _autoOffTimer => _globalState.autoOffTimer;
  set _autoOffTimer(Timer? value) => _globalState.autoOffTimer = value;

  bool get _sosActive => _globalState.sosActive;
  set _sosActive(bool value) => _globalState.sosActive = value;

  Color get _screenLightColor => _globalState.screenLightColor;
  set _screenLightColor(Color value) => _globalState.screenLightColor = value;

  @override
  void initState() {
    super.initState();
    _checkTorchAvailability();
    _updateBatteryLevel();
    _loadSavedScreenLightColor();
    // Update battery level every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _updateBatteryLevel();
    });
  }

  // Load saved screen light color from persistent storage
  Future<void> _loadSavedScreenLightColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorValue = prefs.getInt('screen_light_color');
      if (colorValue != null && mounted) {
        setState(() {
          _screenLightColor = Color(colorValue);
        });
      }
    } catch (e) {
      debugPrint('Failed to load screen light color: $e');
    }
  }

  // Save screen light color to persistent storage
  Future<void> _saveScreenLightColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('screen_light_color', _screenLightColor.toARGB32());
    } catch (e) {
      debugPrint('Failed to save screen light color: $e');
    }
  }

  @override
  void dispose() {
    // Don't stop modes or cancel timers - let them persist across navigation
    // They will continue running in the background
    super.dispose();
  }

  Future<void> _checkTorchAvailability() async {
    try {
      await TorchLight.isTorchAvailable();
      setState(() {
        _isTorchAvailable = true;
      });
    } catch (e) {
      setState(() {
        _isTorchAvailable = false;
        // If torch unavailable and current mode requires torch, switch to screen light
        if (!_isScreenBasedMode(_currentMode)) {
          _currentMode = FlashlightMode.screenLight;
        }
      });
    }
  }

  Future<void> _updateBatteryLevel() async {
    final level = await _battery.batteryLevel;
    if (mounted) {
      setState(() {
        _batteryLevel = level;
      });
    }
  }

  // Check if a mode is screen-based (doesn't require torch)
  bool _isScreenBasedMode(FlashlightMode mode) {
    return mode == FlashlightMode.redLight ||
        mode == FlashlightMode.screenLight;
  }

  Future<void> _toggleFlashlight() async {
    // Screen-based modes don't need torch, so skip availability check
    final needsTorch = _currentMode != FlashlightMode.redLight &&
        _currentMode != FlashlightMode.screenLight;

    if (needsTorch && !_isTorchAvailable) {
      _showError('Flashlight not available on this device');
      return;
    }

    try {
      if (_isFlashlightOn) {
        // Stop all modes first, then disable torch
        setState(() {
          _isFlashlightOn = false;
        });
        _stopAllModes();
        // Restore original brightness for screen light modes
        if ((_currentMode == FlashlightMode.redLight ||
                _currentMode == FlashlightMode.screenLight) &&
            _originalBrightness != null) {
          try {
            await ScreenBrightness().setScreenBrightness(_originalBrightness!);
            _originalBrightness = null;
          } catch (e) {
            debugPrint('Failed to restore screen brightness: $e');
          }
        }
        // Add delay to ensure timer operations complete
        await Future.delayed(const Duration(milliseconds: 100));
        // Force disable torch multiple times to ensure it's off
        try {
          await TorchLight.disableTorch();
        } catch (e) {
          debugPrint('Failed to disable torch (first attempt): $e');
        }
        await Future.delayed(const Duration(milliseconds: 50));
        try {
          await TorchLight.disableTorch();
        } catch (e) {
          debugPrint('Failed to disable torch (retry): $e');
        }
      } else {
        setState(() {
          _isFlashlightOn = true;
        });
        // Only enable torch for non-screen modes
        if (needsTorch) {
          await TorchLight.enableTorch();
        }
        // Start selected mode
        switch (_currentMode) {
          case FlashlightMode.strobe:
            _startStrobe();
            break;
          case FlashlightMode.sos:
            _startSOS();
            break;
          case FlashlightMode.redLight:
          case FlashlightMode.screenLight:
            // Screen-based modes, just set brightness (no torch needed)
            try {
              _originalBrightness = await ScreenBrightness().current;
              await _updateScreenBrightness();
            } catch (e) {
              debugPrint('Failed to set screen brightness: $e');
            }
            break;
          default:
            break;
        }
      }
    } catch (e) {
      _showError('Failed to control flashlight: $e');
    }
  }

  // Update screen brightness based on brightness setting (20% to 100%)
  Future<void> _updateScreenBrightness() async {
    try {
      // Brightness slider is already 0.2 to 1.0, so use it directly
      await ScreenBrightness().setScreenBrightness(_brightness);
    } catch (e) {
      debugPrint('Failed to update screen brightness: $e');
    }
  }

  void _stopAllModes() {
    _strobeTimer?.cancel();
    _strobeTimer = null;
    _sosActive = false;
    _autoOffTimer?.cancel();
    _autoOffTimer = null;
    _autoOffMinutes = null;
    _autoOffStartTime = null;
  }

  void _setMode(FlashlightMode mode) {
    setState(() {
      _currentMode = mode;
    });

    if (_isFlashlightOn) {
      // Re-apply the flashlight with new mode
      _toggleFlashlight().then((_) => _toggleFlashlight());
    }
  }

  void _startStrobe() {
    final interval = Duration(milliseconds: (500 / _strobeFrequency).round());
    _strobeTimer = Timer.periodic(interval, (_) async {
      if (!_isFlashlightOn) return;
      try {
        await TorchLight.disableTorch();
        if (!_isFlashlightOn) return; // Check again after async operation
        await Future.delayed(const Duration(milliseconds: 50));
        if (!_isFlashlightOn) return; // Check again after delay
        await TorchLight.enableTorch();
      } catch (e) {
        // Ignore errors during strobe
      }
    });
  }

  void _startSOS() {
    // SOS pattern using custom message (defaults to "SOS")
    _sosActive = true;
    _runSOSPattern();
  }

  Future<void> _runSOSPattern() async {
    if (!_sosActive || !_isFlashlightOn) return;

    // Convert message to Morse code pattern
    final pattern = _convertToMorseCode(_customSOSMessage);

    try {
      for (var i = 0; i < pattern.length; i += 2) {
        if (!_sosActive || !_isFlashlightOn) break;

        await TorchLight.enableTorch();
        await Future.delayed(Duration(milliseconds: pattern[i]));
        await TorchLight.disableTorch();
        await Future.delayed(Duration(milliseconds: pattern[i + 1]));
      }

      if (_sosActive && _isFlashlightOn) {
        _runSOSPattern(); // Repeat
      }
    } catch (e) {
      // Stop SOS on error
      _sosActive = false;
    }
  }

  // Convert text to Morse code timing pattern (in milliseconds)
  List<int> _convertToMorseCode(String text) {
    // Morse code timing standards:
    // Dot = 200ms, Dash = 600ms
    // Gap between parts of same letter = 200ms
    // Gap between letters = 600ms
    // Gap between words = 1000ms

    const dot = 200;
    const dash = 600;
    const gapPart = 200;
    const gapLetter = 600;
    const gapWord = 1000;

    final morseMap = {
      'A': '.-',
      'B': '-...',
      'C': '-.-.',
      'D': '-..',
      'E': '.',
      'F': '..-.',
      'G': '--.',
      'H': '....',
      'I': '..',
      'J': '.---',
      'K': '-.-',
      'L': '.-..',
      'M': '--',
      'N': '-.',
      'O': '---',
      'P': '.--.',
      'Q': '--.-',
      'R': '.-.',
      'S': '...',
      'T': '-',
      'U': '..-',
      'V': '...-',
      'W': '.--',
      'X': '-..-',
      'Y': '-.--',
      'Z': '--..',
      '0': '-----',
      '1': '.----',
      '2': '..---',
      '3': '...--',
      '4': '....-',
      '5': '.....',
      '6': '-....',
      '7': '--...',
      '8': '---..',
      '9': '----.',
    };

    List<int> pattern = [];
    final words = text.toUpperCase().split(' ');

    for (int w = 0; w < words.length; w++) {
      final word = words[w];
      for (int c = 0; c < word.length; c++) {
        final char = word[c];
        final morse = morseMap[char];

        if (morse != null) {
          for (int i = 0; i < morse.length; i++) {
            final symbol = morse[i];
            if (symbol == '.') {
              pattern.addAll([dot, gapPart]);
            } else if (symbol == '-') {
              pattern.addAll([dash, gapPart]);
            }
          }
          // Add letter gap (remove last gapPart, add gapLetter)
          if (pattern.isNotEmpty) {
            pattern.removeLast();
            pattern.add(gapLetter);
          }
        }
      }
      // Add word gap (remove last gapLetter, add gapWord)
      if (w < words.length - 1 && pattern.isNotEmpty) {
        pattern.removeLast();
        pattern.add(gapWord);
      }
    }

    return pattern;
  }

  // Show dialog to customize SOS message
  void _showSOSCustomizationDialog() {
    final controller = TextEditingController(text: _customSOSMessage);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Customize SOS Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a custom message to flash in Morse code. Default is "SOS".',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'SOS',
                border: OutlineInputBorder(),
              ),
              maxLength: 20,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 8),
            const Text(
              'Supports: A-Z, 0-9, spaces',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Reset to default
              setState(() {
                _customSOSMessage = 'SOS';
              });
              Navigator.of(context).pop();
            },
            child: const Text('Reset to SOS'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newMessage = controller.text.trim().toUpperCase();
              if (newMessage.isNotEmpty) {
                // Filter to only valid characters
                final filtered = newMessage.split('').where((c) {
                  return (c.codeUnitAt(0) >= 65 &&
                          c.codeUnitAt(0) <= 90) || // A-Z
                      (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) || // 0-9
                      c == ' ';
                }).join();

                setState(() {
                  _customSOSMessage = filtered.isEmpty ? 'SOS' : filtered;
                });
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _setAutoOff(int? minutes) {
    _autoOffTimer?.cancel();

    if (minutes == null) {
      setState(() {
        _autoOffMinutes = null;
        _autoOffStartTime = null;
      });
      return;
    }

    setState(() {
      _autoOffMinutes = minutes;
      _autoOffStartTime = DateTime.now();
    });

    _autoOffTimer = Timer(Duration(minutes: minutes), () {
      if (_isFlashlightOn) {
        _toggleFlashlight();
        _showNotification('Flashlight auto-off after $minutes minutes');
      }
    });
  }

  void _openConcertMode() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ConcertModeScreen()));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _getRemainingTime() {
    if (_autoOffStartTime == null || _autoOffMinutes == null) return '';

    final elapsed = DateTime.now().difference(_autoOffStartTime!);
    final remaining = Duration(minutes: _autoOffMinutes!) - elapsed;

    if (remaining.isNegative) return '0:00';

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // Get contrasting color for text visibility
  Color _getContrastColor(Color backgroundColor) {
    // Calculate relative luminance
    final luminance = backgroundColor.computeLuminance();
    // Return black for light backgrounds, white for dark backgrounds
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // Get color name for preset colors or 'Custom' for non-preset colors
  String _getColorName(Color color) {
    // Define preset colors with their names
    final presetColors = {
      Colors.white: 'White',
      Colors.red: 'Red',
      Colors.orange: 'Orange',
      Colors.yellow: 'Yellow',
      Colors.green: 'Green',
      Colors.cyan: 'Cyan',
      Colors.blue: 'Blue',
      Colors.purple: 'Purple',
      Colors.pink: 'Pink',
      Colors.amber: 'Amber',
    };

    // Check if color matches any preset (compare ARGB values)
    for (final entry in presetColors.entries) {
      final presetARGB = entry.key.toARGB32();
      final colorARGB = color.toARGB32();
      if (presetARGB == colorARGB) {
        return entry.value;
      }
    }

    // Return 'Custom' for non-preset colors
    return 'Custom';
  }

  // Show color picker dialog
  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose Color'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current color preview
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _screenLightColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(height: 24),
                // Preset colors
                Text('Presets', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildDialogColorButton(
                      Colors.white,
                      'White',
                      setDialogState,
                    ),
                    _buildDialogColorButton(Colors.red, 'Red', setDialogState),
                    _buildDialogColorButton(
                      Colors.orange,
                      'Orange',
                      setDialogState,
                    ),
                    _buildDialogColorButton(
                      Colors.yellow,
                      'Yellow',
                      setDialogState,
                    ),
                    _buildDialogColorButton(
                      Colors.green,
                      'Green',
                      setDialogState,
                    ),
                    _buildDialogColorButton(
                      Colors.cyan,
                      'Cyan',
                      setDialogState,
                    ),
                    _buildDialogColorButton(
                      Colors.blue,
                      'Blue',
                      setDialogState,
                    ),
                    _buildDialogColorButton(
                      Colors.purple,
                      'Purple',
                      setDialogState,
                    ),
                    _buildDialogColorButton(
                      Colors.pink,
                      'Pink',
                      setDialogState,
                    ),
                    _buildDialogColorButton(
                      Colors.amber,
                      'Amber',
                      setDialogState,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                // Custom color section
                Text(
                  'Custom Color',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 16),
                // Color palette picker
                _buildColorPalettePicker(setDialogState),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  // Build interactive color palette picker
  Widget _buildColorPalettePicker(StateSetter setDialogState) {
    final hsvColor = HSVColor.fromColor(_screenLightColor);

    return Column(
      children: [
        // Saturation/Value picker (main color palette)
        GestureDetector(
          onPanStart: (details) =>
              _updateColorFromPalette(details.localPosition, setDialogState),
          onPanUpdate: (details) =>
              _updateColorFromPalette(details.localPosition, setDialogState),
          child: Container(
            width: 280,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: ColorPalettePainter(hue: hsvColor.hue),
                child: Stack(
                  children: [
                    // Color selector indicator
                    Positioned(
                      left: hsvColor.saturation * 280 - 10,
                      top: (1 - hsvColor.value) * 200 - 10,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Hue slider
        GestureDetector(
          onPanStart: (details) =>
              _updateHue(details.localPosition, setDialogState),
          onPanUpdate: (details) =>
              _updateHue(details.localPosition, setDialogState),
          child: Container(
            width: 280,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: HueSliderPainter(),
                child: Stack(
                  children: [
                    // Hue selector indicator
                    Positioned(
                      left: (hsvColor.hue / 360) * 280 - 3,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 6,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Update color from palette position
  void _updateColorFromPalette(Offset position, StateSetter setDialogState) {
    final hsvColor = HSVColor.fromColor(_screenLightColor);
    final saturation = (position.dx / 280).clamp(0.0, 1.0);
    final value = (1 - (position.dy / 200)).clamp(0.0, 1.0);

    setState(() {
      _screenLightColor = hsvColor
          .withSaturation(saturation)
          .withValue(value)
          .toColor();
    });
    setDialogState(() {});
    _saveScreenLightColor();
  }

  // Update hue from slider position
  void _updateHue(Offset position, StateSetter setDialogState) {
    final hsvColor = HSVColor.fromColor(_screenLightColor);
    final hue = ((position.dx / 280) * 360).clamp(0.0, 360.0);

    setState(() {
      _screenLightColor = hsvColor.withHue(hue).toColor();
    });
    setDialogState(() {});
    _saveScreenLightColor();
  }

  // Build color button for dialog (smaller version)
  Widget _buildDialogColorButton(
    Color color,
    String label,
    StateSetter setDialogState,
  ) {
    final isSelected = _screenLightColor.toARGB32() == color.toARGB32();
    return GestureDetector(
      onTap: () {
        setState(() {
          _screenLightColor = color;
        });
        setDialogState(() {});
        _saveScreenLightColor();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 8,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
              fontWeight: isSelected ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Screen-based light modes use full screen overlay
    if ((_currentMode == FlashlightMode.redLight ||
            _currentMode == FlashlightMode.screenLight) &&
        _isFlashlightOn) {
      final isRedLight = _currentMode == FlashlightMode.redLight;
      // Use solid colors - brightness is controlled by device screen brightness
      final backgroundColor = isRedLight
          ? Colors.red.shade900
          : _screenLightColor;
      final textColor = isRedLight
          ? Colors.red.shade100
          : _getContrastColor(_screenLightColor);
      final buttonColor = isRedLight ? Colors.red.shade800 : _screenLightColor;

      return Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isRedLight ? 'Red Light Mode' : 'Screen Light',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isRedLight
                      ? 'Night vision preserved'
                      : 'Soft ambient lighting',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _toggleFlashlight,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: textColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Turn OFF', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AniniTools'),
        actions: [
          // Battery indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(
                  _batteryLevel > 20
                      ? (_batteryLevel > 80
                            ? Icons.battery_full
                            : Icons.battery_std)
                      : Icons.battery_alert,
                  color: _batteryLevel > 20
                      ? colorScheme.onSurface
                      : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  '$_batteryLevel%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _batteryLevel > 20
                        ? colorScheme.onSurface
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content - centered vertically
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Large flashlight button
                  GestureDetector(
                    onTap: _toggleFlashlight,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isFlashlightOn
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        boxShadow: _isFlashlightOn
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _isFlashlightOn
                            ? Icons.flashlight_on
                            : Icons.flashlight_off,
                        size: 80,
                        color: _isFlashlightOn
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Status text
                  Text(
                    _isFlashlightOn
                        ? 'Flashlight ON${_currentMode != FlashlightMode.normal ? ' - ${_currentMode.label}' : ''}'
                        : 'Tap to turn ON',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: _isFlashlightOn
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),

                  // Auto-off timer display
                  if (_autoOffMinutes != null && _isFlashlightOn) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Auto-off in ${_getRemainingTime()}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Torch unavailable info banner
                  if (!_isTorchAvailable)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.onErrorContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Torch not available on this device. Only screen-based modes are shown.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!_isTorchAvailable) const SizedBox(height: 16),

                  // Quick mode selection chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: FlashlightMode.values
                          .where((mode) =>
                              _isTorchAvailable || _isScreenBasedMode(mode))
                          .map((mode) {
                        final isSelected = _currentMode == mode;
                        return FilterChip(
                          label: Text(mode.label),
                          avatar: Icon(mode.icon, size: 18),
                          selected: isSelected,
                          onSelected: (_) => _setMode(mode),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom controls - overlapping sheet
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Quick actions
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openConcertMode,
                              icon: const Icon(Icons.music_note),
                              label: const Text('Concert Mode'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showAdvancedOptions = !_showAdvancedOptions;
                              });
                            },
                            icon: Icon(
                              _showAdvancedOptions
                                  ? Icons.expand_less
                                  : Icons.tune,
                            ),
                            label: Text(
                              _showAdvancedOptions ? 'Less' : 'Options',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Advanced options (expandable)
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _buildAdvancedOptions(theme, colorScheme),
                      crossFadeState: _showAdvancedOptions
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),

            // SOS message customization (only shown when SOS mode selected)
            if (_currentMode == FlashlightMode.sos) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SOS Message', style: theme.textTheme.titleSmall),
                  OutlinedButton.icon(
                    onPressed: _showSOSCustomizationDialog,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Customize'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Message:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _customSOSMessage,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Strobe frequency (only shown when strobe mode selected)
            if (_currentMode == FlashlightMode.strobe) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Strobe Speed', style: theme.textTheme.titleSmall),
                  Text(
                    '${_strobeFrequency.toStringAsFixed(1)} Hz',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _strobeFrequency,
                min: 1.0,
                max: 20.0,
                divisions: 19,
                onChanged: (value) {
                  setState(() {
                    _strobeFrequency = value;
                  });
                  if (_isFlashlightOn) {
                    _strobeTimer?.cancel();
                    _startStrobe();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],

            // Brightness (shown for red light and screen light modes)
            if (_currentMode == FlashlightMode.redLight ||
                _currentMode == FlashlightMode.screenLight) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Brightness', style: theme.textTheme.titleSmall),
                  Text(
                    '${(_brightness * 100).toInt()}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _brightness,
                min: 0.2,
                max: 1.0,
                divisions: 8,
                onChanged: (value) {
                  setState(() {
                    _brightness = value;
                  });
                  // Update device screen brightness in real-time
                  if (_isFlashlightOn) {
                    _updateScreenBrightness();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],

            // Color picker (only shown for screen light mode)
            if (_currentMode == FlashlightMode.screenLight) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Color', style: theme.textTheme.titleSmall),
                  OutlinedButton.icon(
                    onPressed: _showColorPicker,
                    icon: const Icon(Icons.palette, size: 18),
                    label: const Text('Choose'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Show current selected color
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  color: _screenLightColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _getColorName(_screenLightColor),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _getContrastColor(_screenLightColor),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Auto-off timer
            Text('Auto-off Timer', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Off'),
                  selected: _autoOffMinutes == null,
                  onSelected: (_) => _setAutoOff(null),
                ),
                ChoiceChip(
                  label: const Text('5 min'),
                  selected: _autoOffMinutes == 5,
                  onSelected: (_) => _setAutoOff(5),
                ),
                ChoiceChip(
                  label: const Text('10 min'),
                  selected: _autoOffMinutes == 10,
                  onSelected: (_) => _setAutoOff(10),
                ),
                ChoiceChip(
                  label: const Text('15 min'),
                  selected: _autoOffMinutes == 15,
                  onSelected: (_) => _setAutoOff(15),
                ),
                ChoiceChip(
                  label: const Text('30 min'),
                  selected: _autoOffMinutes == 30,
                  onSelected: (_) => _setAutoOff(30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum FlashlightMode {
  normal('Normal', Icons.flashlight_on),
  strobe('Strobe', Icons.flash_on),
  sos('SOS', Icons.sos),
  redLight('Red Light', Icons.nightlight),
  screenLight('Screen Light', Icons.light_mode);

  final String label;
  final IconData icon;
  const FlashlightMode(this.label, this.icon);
}
