import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';
import '../../models/text_style_config.dart';
import '../../services/beat_detector.dart';
import '../../widgets/painters/color_picker_painters.dart';
import '../../widgets/text_styles/led_matrix_renderer.dart';
import '../../widgets/text_styles/neon_glow_renderer.dart';
import '../../widgets/text_styles/seven_segment_renderer.dart';
import '../../widgets/text_styles/pixel_retro_renderer.dart';
import '../../widgets/text_styles/stadium_bulb_renderer.dart';

/// Concert Mode - Full-screen scrolling text with beat-sync capabilities
/// Social-first design for TikTok/Instagram viral content
class ConcertModeScreen extends StatefulWidget {
  const ConcertModeScreen({super.key});

  @override
  State<ConcertModeScreen> createState() => _ConcertModeScreenState();
}

class _ConcertModeScreenState extends State<ConcertModeScreen>
    with SingleTickerProviderStateMixin {
  // Text and display
  String _message = 'I ❤️ MUSIC';
  final TextEditingController _messageController = TextEditingController();
  ScrollDirection _scrollDirection = ScrollDirection.horizontal;
  double _scrollSpeed = 1.0;
  double _fontSize = 72.0;
  FontWeight _fontWeight = FontWeight.bold;

  // Colors and effects
  ColorMode _colorMode = ColorMode.solid;
  Color _solidColor = Colors.white;
  List<Color> _gradientColors = [Colors.purple, Colors.pink, Colors.orange];
  Color _backgroundColor = Colors.black;
  bool _useCustomBackground = false;
  EffectMode _effectMode = EffectMode.none;

  // Text display styles
  TextDisplayStyle _textStyle = TextDisplayStyle.normal;
  LEDMatrixConfig _ledConfig = const LEDMatrixConfig();
  NeonGlowConfig _neonConfig = const NeonGlowConfig();
  SevenSegmentConfig _sevenSegmentConfig = const SevenSegmentConfig();
  PixelRetroConfig _pixelConfig = const PixelRetroConfig();
  StadiumBulbConfig _stadiumConfig = const StadiumBulbConfig();

  // Beat sync and strobe
  bool _beatSyncEnabled = false;
  double _strobeFrequency = 2.0; // Hz — also sets the min interval between beats
  double _beatSensitivity = 0.5; // 0.0 (low) to 1.0 (high) - user adjustable

  // Beat detection is delegated to a dedicated service so this screen can
  // stay focused on rendering. The detector fires sustain events that we
  // translate into torch on/off.
  final BeatDetector _beatDetector = BeatDetector();
  bool _flashlightOn = false;

  // Screen state
  bool _isFullscreen = false;
  bool _showControls = true;
  double? _originalBrightness;
  ScreenOrientation _screenOrientation = ScreenOrientation.auto;

  // Animation
  late AnimationController _scrollController;
  late Animation<Offset> _scrollAnimation;

  // Templates
  List<MessageTemplate> _templates = [];
  List<MessageTemplate> _favorites = [];

  @override
  void initState() {
    super.initState();
    _messageController.text = _message;
    _beatDetector
      ..sensitivity = _beatSensitivity
      ..minimumBeatIntervalMs = (1000 / _strobeFrequency).round()
      ..onSustainChange = _handleBeatSustain;
    _initializeTemplates();
    _loadFavorites();
    _loadSettings();
    _setupScrollAnimation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    // Fire-and-forget full teardown. The detector stops the audio stream
    // and releases the native recorder; we also force the torch off here
    // in case dispose() races ahead of the sustain callback.
    _beatDetector.dispose();
    if (_flashlightOn) {
      TorchLight.disableTorch().catchError((Object e) {
        debugPrint('Failed to disable torch on dispose: $e');
      });
      _flashlightOn = false;
    }

    _restoreBrightness();
    // Ensure orientation is reset when leaving concert mode screen entirely
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  /// BeatDetector's sustain callback — route to torch on/off.
  void _handleBeatSustain(bool sustainOn) {
    if (sustainOn) {
      _turnFlashlightOn();
    } else {
      _turnFlashlightOff();
    }
  }

  void _initializeTemplates() {
    _templates = [
      MessageTemplate('MARRY ME 💍', Colors.white, [Colors.red, Colors.pink]),
      MessageTemplate('HAPPY BIRTHDAY 🎂', Colors.yellow,
          [Colors.orange, Colors.yellow, Colors.pink]),
      MessageTemplate(
          'I ❤️ MUSIC', Colors.red, [Colors.red, Colors.pink, Colors.purple]),
      MessageTemplate('🎉 PARTY 🎉', Colors.cyan,
          [Colors.cyan, Colors.purple, Colors.pink]),
      MessageTemplate('💜', Colors.purple, [Colors.purple, Colors.pink]),
      MessageTemplate(
          '🌟 STAR 🌟', Colors.amber, [Colors.amber, Colors.orange]),
      MessageTemplate('DANCE 💃', Colors.pink,
          [Colors.pink, Colors.purple, Colors.blue]),
      MessageTemplate(
          '🔥 LIT 🔥', Colors.orange, [Colors.red, Colors.orange, Colors.yellow]),
      MessageTemplate('LOVE YOU ❤️', Colors.red, [Colors.red, Colors.pink]),
      MessageTemplate(
          'BEST NIGHT EVER ✨', Colors.white, [Colors.blue, Colors.purple, Colors.pink]),
    ];
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList('concert_favorites') ?? [];
    setState(() {
      _favorites = favoritesJson
          .map((json) => MessageTemplate.fromJson(jsonDecode(json)))
          .toList();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Load message
      _message = prefs.getString('concert_message') ?? 'I ❤️ MUSIC';
      _messageController.text = _message;

      // Load scroll settings
      final scrollDirIndex = prefs.getInt('concert_scroll_direction') ?? 0;
      _scrollDirection = ScrollDirection.values[scrollDirIndex];
      _scrollSpeed = prefs.getDouble('concert_scroll_speed') ?? 1.0;

      // Load text settings
      _fontSize = prefs.getDouble('concert_font_size') ?? 72.0;
      final fontWeightIndex = prefs.getInt('concert_font_weight') ?? 7;
      _fontWeight = FontWeight.values[fontWeightIndex];

      // Load color settings
      final colorModeIndex = prefs.getInt('concert_color_mode') ?? 0;
      _colorMode = ColorMode.values[colorModeIndex];
      final solidColorValue = prefs.getInt('concert_solid_color');
      if (solidColorValue != null) {
        _solidColor = Color(solidColorValue);
      }
      final gradientColorsJson = prefs.getString('concert_gradient_colors');
      if (gradientColorsJson != null) {
        final colorValues = (jsonDecode(gradientColorsJson) as List)
            .map((v) => v as int)
            .toList();
        _gradientColors = colorValues.map((v) => Color(v)).toList();
      }

      // Load effect settings
      final effectModeIndex = prefs.getInt('concert_effect_mode') ?? 0;
      _effectMode = EffectMode.values[effectModeIndex];

      // Load text style settings
      final textStyleIndex = prefs.getInt('concert_text_style') ?? 0;
      _textStyle = TextDisplayStyle.values[textStyleIndex];
      final ledConfigJson = prefs.getString('concert_led_config');
      if (ledConfigJson != null) {
        _ledConfig = LEDMatrixConfig.fromJson(jsonDecode(ledConfigJson));
      }
      final neonConfigJson = prefs.getString('concert_neon_config');
      if (neonConfigJson != null) {
        _neonConfig = NeonGlowConfig.fromJson(jsonDecode(neonConfigJson));
      }
      final sevenSegmentConfigJson = prefs.getString('concert_seven_segment_config');
      if (sevenSegmentConfigJson != null) {
        _sevenSegmentConfig = SevenSegmentConfig.fromJson(jsonDecode(sevenSegmentConfigJson));
      }
      final pixelConfigJson = prefs.getString('concert_pixel_config');
      if (pixelConfigJson != null) {
        _pixelConfig = PixelRetroConfig.fromJson(jsonDecode(pixelConfigJson));
      }
      final stadiumConfigJson = prefs.getString('concert_stadium_config');
      if (stadiumConfigJson != null) {
        _stadiumConfig = StadiumBulbConfig.fromJson(jsonDecode(stadiumConfigJson));
      }

      // Load beat sync settings
      _beatSyncEnabled = prefs.getBool('concert_beat_sync') ?? false;
      _strobeFrequency = prefs.getDouble('concert_strobe_frequency') ?? 2.0;
      _beatSensitivity = prefs.getDouble('concert_beat_sensitivity') ?? 0.5;
      // Keep the detector's tuning in sync with the just-loaded values.
      _beatDetector
        ..sensitivity = _beatSensitivity
        ..minimumBeatIntervalMs = (1000 / _strobeFrequency).round();

      // Load screen orientation
      final orientationIndex = prefs.getInt('concert_orientation') ?? 0;
      _screenOrientation = ScreenOrientation.values[orientationIndex];

      // Load background color settings
      final backgroundColorValue = prefs.getInt('concert_background_color');
      if (backgroundColorValue != null) {
        _backgroundColor = Color(backgroundColorValue);
      }
      _useCustomBackground = prefs.getBool('concert_use_custom_background') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Save message
    await prefs.setString('concert_message', _message);

    // Save scroll settings
    await prefs.setInt('concert_scroll_direction', _scrollDirection.index);
    await prefs.setDouble('concert_scroll_speed', _scrollSpeed);

    // Save text settings
    await prefs.setDouble('concert_font_size', _fontSize);
    // ponytail: store index to stay compatible with FontWeight.values[index] load above
    await prefs.setInt('concert_font_weight', _fontWeight.value ~/ 100 - 1);

    // Save color settings
    await prefs.setInt('concert_color_mode', _colorMode.index);
    await prefs.setInt('concert_solid_color', _solidColor.toARGB32());
    await prefs.setString('concert_gradient_colors',
        jsonEncode(_gradientColors.map((c) => c.toARGB32()).toList()));

    // Save effect settings
    await prefs.setInt('concert_effect_mode', _effectMode.index);

    // Save text style settings
    await prefs.setInt('concert_text_style', _textStyle.index);
    await prefs.setString('concert_led_config', jsonEncode(_ledConfig.toJson()));
    await prefs.setString('concert_neon_config', jsonEncode(_neonConfig.toJson()));
    await prefs.setString('concert_seven_segment_config', jsonEncode(_sevenSegmentConfig.toJson()));
    await prefs.setString('concert_pixel_config', jsonEncode(_pixelConfig.toJson()));
    await prefs.setString('concert_stadium_config', jsonEncode(_stadiumConfig.toJson()));

    // Save beat sync settings
    await prefs.setBool('concert_beat_sync', _beatSyncEnabled);
    await prefs.setDouble('concert_strobe_frequency', _strobeFrequency);
    await prefs.setDouble('concert_beat_sensitivity', _beatSensitivity);

    // Save screen orientation
    await prefs.setInt('concert_orientation', _screenOrientation.index);

    // Save background color settings
    await prefs.setInt('concert_background_color', _backgroundColor.toARGB32());
    await prefs.setBool('concert_use_custom_background', _useCustomBackground);
  }

  Future<void> _saveFavorite(MessageTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    _favorites.add(template);
    final favoritesJson =
        _favorites.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList('concert_favorites', favoritesJson);
    setState(() {});
  }

  Future<void> _removeFavorite(MessageTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    _favorites.removeWhere((t) => t.text == template.text);
    final favoritesJson =
        _favorites.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList('concert_favorites', favoritesJson);
    setState(() {});
  }

  void _setupScrollAnimation() {
    _scrollController = AnimationController(
      duration: Duration(seconds: (10 / _scrollSpeed).round()),
      vsync: this,
    )..repeat();

    _updateScrollAnimation();
  }

  void _updateScrollAnimation() {
    if (_scrollDirection == ScrollDirection.horizontal) {
      _scrollAnimation = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: const Offset(-1.0, 0.0),
      ).animate(CurvedAnimation(
        parent: _scrollController,
        curve: Curves.linear,
      ));
    } else {
      _scrollAnimation = Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: const Offset(0.0, -1.0),
      ).animate(CurvedAnimation(
        parent: _scrollController,
        curve: Curves.linear,
      ));
    }
    _scrollController.duration = Duration(seconds: (10 / _scrollSpeed).round());
  }

  Future<void> _enterFullscreen() async {
    setState(() {
      _isFullscreen = true;
      _showControls = false;
    });

    // Set screen orientation
    switch (_screenOrientation) {
      case ScreenOrientation.portrait:
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        break;
      case ScreenOrientation.landscape:
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        break;
      case ScreenOrientation.auto:
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        break;
    }

    // Set brightness to max
    try {
      _originalBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (e) {
      debugPrint('Failed to set max brightness: $e');
    }

    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Start scrolling animation
    _scrollController.repeat();

    // Start beat sync if enabled
    if (_beatSyncEnabled) {
      _startBeatSync();
    }
  }

  Future<void> _exitFullscreen() async {
    setState(() {
      _isFullscreen = false;
      _showControls = true;
    });

    // Force portrait orientation first to rotate back from landscape
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Restore brightness
    await _restoreBrightness();

    // Show system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Stop animations
    _scrollController.stop();
    _stopBeatSync();

    // After a short delay, allow auto-rotate again
    Future.delayed(const Duration(milliseconds: 300), () {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });
  }

  Future<void> _restoreBrightness() async {
    if (_originalBrightness != null) {
      try {
        await ScreenBrightness().setScreenBrightness(_originalBrightness!);
        _originalBrightness = null;
      } catch (e) {
        debugPrint('Failed to restore brightness: $e');
      }
    }
  }

  Future<void> _startBeatSync() async {
    _beatDetector
      ..sensitivity = _beatSensitivity
      ..minimumBeatIntervalMs = (1000 / _strobeFrequency).round();

    final result = await _beatDetector.start();
    switch (result) {
      case BeatDetectorStartResult.success:
        break;
      case BeatDetectorStartResult.permissionDenied:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission required for beat sync'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        if (mounted) setState(() => _beatSyncEnabled = false);
        break;
      case BeatDetectorStartResult.error:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start beat detection'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        if (mounted) setState(() => _beatSyncEnabled = false);
        break;
    }
  }

  Future<void> _stopBeatSync() async {
    await _beatDetector.stop();
    // Belt-and-suspenders: the sustain callback fires with false on stop,
    // but if the screen is mid-transition the torch may still be on.
    if (_flashlightOn) {
      try {
        await TorchLight.disableTorch();
        _flashlightOn = false;
      } catch (e) {
        debugPrint('Failed to disable torch on beat-sync stop: $e');
      }
    }
  }

  void _turnFlashlightOn() {
    if (!_flashlightOn) {
      TorchLight.enableTorch().then((_) {
        _flashlightOn = true;
      }).catchError((Object e) {
        debugPrint('Failed to enable torch during beat sync: $e');
      });
    }
  }

  void _turnFlashlightOff() {
    if (_flashlightOn) {
      TorchLight.disableTorch().then((_) {
        _flashlightOn = false;
      }).catchError((Object e) {
        debugPrint('Failed to disable torch during beat sync: $e');
      });
    }
  }

  void _applyTemplate(MessageTemplate template) {
    setState(() {
      _message = template.text;
      _messageController.text = template.text;
      if (template.gradientColors.length > 1) {
        _colorMode = ColorMode.gradient;
        _gradientColors = template.gradientColors;
      } else {
        _colorMode = ColorMode.solid;
        _solidColor = template.solidColor;
      }
    });
    _saveSettings();
  }

  void _showTextColorPicker() {
    _showColorPickerDialog(
      title: 'Choose Text Color',
      initialColor: _solidColor,
      onColorSelected: (color) {
        setState(() {
          _solidColor = color;
        });
        _saveSettings();
      },
    );
  }

  void _showBackgroundColorPicker() {
    _showColorPickerDialog(
      title: 'Choose Background Color',
      initialColor: _backgroundColor,
      onColorSelected: (color) {
        setState(() {
          _backgroundColor = color;
        });
        _saveSettings();
      },
    );
  }

  void _showColorPickerDialog({
    required String title,
    required Color initialColor,
    required Function(Color) onColorSelected,
  }) {
    Color selectedColor = initialColor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Current color preview
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: selectedColor,
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
                    _buildColorPickerButton(Colors.white, setDialogState, selectedColor, (c) {
                      selectedColor = c;
                      onColorSelected(c);
                    }),
                    _buildColorPickerButton(Colors.black, setDialogState, selectedColor, (c) {
                      selectedColor = c;
                      onColorSelected(c);
                    }),
                    _buildColorPickerButton(Colors.red, setDialogState, selectedColor, (c) {
                      selectedColor = c;
                      onColorSelected(c);
                    }),
                    _buildColorPickerButton(Colors.orange, setDialogState, selectedColor, (c) {
                      selectedColor = c;
                      onColorSelected(c);
                    }),
                    _buildColorPickerButton(Colors.yellow, setDialogState, selectedColor, (c) {
                      selectedColor = c;
                      onColorSelected(c);
                    }),
                    _buildColorPickerButton(Colors.green, setDialogState, selectedColor, (c) {
                      selectedColor = c;
                      onColorSelected(c);
                    }),
                    _buildColorPickerButton(Colors.cyan, setDialogState, selectedColor, (c) {
                      selectedColor = c;
                      onColorSelected(c);
                    }),
                    _buildColorPickerButton(Colors.blue, setDialogState, selectedColor, (c) {
                      selectedColor = c;
                      onColorSelected(c);
                    }),
                    _buildColorPickerButton(Colors.purple, setDialogState, selectedColor, (c) {
                      selectedColor = c;
                      onColorSelected(c);
                    }),
                    _buildColorPickerButton(Colors.pink, setDialogState, selectedColor, (c) {
                      selectedColor = c;
                      onColorSelected(c);
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                // Custom color section
                Text('Custom Color', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 16),
                _buildColorPalettePicker(selectedColor, setDialogState, (c) {
                  selectedColor = c;
                  onColorSelected(c);
                }),
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

  Widget _buildColorPickerButton(
    Color color,
    StateSetter setDialogState,
    Color selectedColor,
    Function(Color) onColorSelected,
  ) {
    final isSelected = selectedColor.toARGB32() == color.toARGB32();
    return GestureDetector(
      onTap: () {
        setDialogState(() {});
        onColorSelected(color);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }

  Widget _buildColorPalettePicker(
    Color selectedColor,
    StateSetter setDialogState,
    Function(Color) onColorSelected,
  ) {
    final hsvColor = HSVColor.fromColor(selectedColor);

    return Column(
      children: [
        // Saturation/Value picker
        GestureDetector(
          onPanStart: (details) =>
              _updateColorPickerPalette(details.localPosition, hsvColor.hue, setDialogState, onColorSelected),
          onPanUpdate: (details) =>
              _updateColorPickerPalette(details.localPosition, hsvColor.hue, setDialogState, onColorSelected),
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
              _updateColorPickerHue(details.localPosition, hsvColor, setDialogState, onColorSelected),
          onPanUpdate: (details) =>
              _updateColorPickerHue(details.localPosition, hsvColor, setDialogState, onColorSelected),
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

  void _updateColorPickerPalette(
    Offset position,
    double hue,
    StateSetter setDialogState,
    Function(Color) onColorSelected,
  ) {
    final saturation = (position.dx / 280).clamp(0.0, 1.0);
    final value = (1 - (position.dy / 200)).clamp(0.0, 1.0);
    final newColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
    setDialogState(() {});
    onColorSelected(newColor);
  }

  void _updateColorPickerHue(
    Offset position,
    HSVColor currentHsv,
    StateSetter setDialogState,
    Function(Color) onColorSelected,
  ) {
    final hue = ((position.dx / 280) * 360).clamp(0.0, 360.0);
    final newColor = currentHsv.withHue(hue).toColor();
    setDialogState(() {});
    onColorSelected(newColor);
  }

  void _showTemplateLibrary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TemplateLibrarySheet(
        templates: _templates,
        favorites: _favorites,
        onSelectTemplate: (template) {
          _applyTemplate(template);
          Navigator.pop(context);
        },
        onToggleFavorite: (template, isFavorite) {
          if (isFavorite) {
            _saveFavorite(template);
          } else {
            _removeFavorite(template);
          }
        },
      ),
    );
  }

  void _showCustomizationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _CustomizationSheet(
          scrollDirection: _scrollDirection,
          scrollSpeed: _scrollSpeed,
          fontSize: _fontSize,
          fontWeight: _fontWeight,
          colorMode: _colorMode,
          solidColor: _solidColor,
          gradientColors: _gradientColors,
          backgroundColor: _backgroundColor,
          useCustomBackground: _useCustomBackground,
          effectMode: _effectMode,
          textStyle: _textStyle,
          ledConfig: _ledConfig,
          neonConfig: _neonConfig,
          sevenSegmentConfig: _sevenSegmentConfig,
          pixelConfig: _pixelConfig,
          stadiumConfig: _stadiumConfig,
          beatSyncEnabled: _beatSyncEnabled,
          strobeFrequency: _strobeFrequency,
          beatSensitivity: _beatSensitivity,
          screenOrientation: _screenOrientation,
          onShowTextColorPicker: _showTextColorPicker,
          onShowBackgroundColorPicker: _showBackgroundColorPicker,
          onScrollDirectionChanged: (value) {
            setState(() => _scrollDirection = value);
            setDialogState(() {});
            _saveSettings();
          },
          onScrollSpeedChanged: (value) {
            setState(() => _scrollSpeed = value);
            _updateScrollAnimation();
            setDialogState(() {});
            _saveSettings();
          },
          onFontSizeChanged: (value) {
            setState(() => _fontSize = value);
            setDialogState(() {});
            _saveSettings();
          },
          onFontWeightChanged: (value) {
            setState(() => _fontWeight = value);
            setDialogState(() {});
            _saveSettings();
          },
          onColorModeChanged: (value) {
            setState(() => _colorMode = value);
            setDialogState(() {});
            _saveSettings();
          },
          onSolidColorChanged: (value) {
            setState(() => _solidColor = value);
            setDialogState(() {});
            _saveSettings();
          },
          onGradientColorsChanged: (value) {
            setState(() => _gradientColors = value);
            setDialogState(() {});
            _saveSettings();
          },
          onUseCustomBackgroundChanged: (value) {
            setState(() => _useCustomBackground = value);
            setDialogState(() {});
            _saveSettings();
          },
          onEffectModeChanged: (value) {
            setState(() => _effectMode = value);
            setDialogState(() {});
            _saveSettings();
          },
          onTextStyleChanged: (value) {
            setState(() => _textStyle = value);
            setDialogState(() {});
            _saveSettings();
          },
          onLedConfigChanged: (value) {
            setState(() => _ledConfig = value);
            setDialogState(() {});
            _saveSettings();
          },
          onNeonConfigChanged: (value) {
            setState(() => _neonConfig = value);
            setDialogState(() {});
            _saveSettings();
          },
          onSevenSegmentConfigChanged: (value) {
            setState(() => _sevenSegmentConfig = value);
            setDialogState(() {});
            _saveSettings();
          },
          onPixelConfigChanged: (value) {
            setState(() => _pixelConfig = value);
            setDialogState(() {});
            _saveSettings();
          },
          onStadiumConfigChanged: (value) {
            setState(() => _stadiumConfig = value);
            setDialogState(() {});
            _saveSettings();
          },
          onBeatSyncChanged: (value) {
            setState(() => _beatSyncEnabled = value);
            setDialogState(() {});
            _saveSettings();
          },
          onStrobeFrequencyChanged: (value) {
            setState(() => _strobeFrequency = value);
            _beatDetector.minimumBeatIntervalMs = (1000 / value).round();
            setDialogState(() {});
            _saveSettings();
          },
          onBeatSensitivityChanged: (value) {
            setState(() => _beatSensitivity = value);
            _beatDetector.sensitivity = value;
            setDialogState(() {});
            _saveSettings();
          },
          onScreenOrientationChanged: (value) {
            setState(() => _screenOrientation = value);
            setDialogState(() {});
            _saveSettings();
          },
        ),
      ),
    );
  }

  Widget _buildTextDisplay() {
    // Determine primary color and gradient colors based on color mode
    final Color primaryColor;
    List<Color>? gradientColors;

    switch (_colorMode) {
      case ColorMode.solid:
        primaryColor = _solidColor;
        gradientColors = null;
        break;
      case ColorMode.gradient:
        primaryColor = _gradientColors.isNotEmpty ? _gradientColors.first : Colors.white;
        gradientColors = _gradientColors;
        break;
      case ColorMode.rainbow:
        // Animated rainbow - use current hue position
        final hue = (_scrollController.value * 360) % 360;
        primaryColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
        // Create rainbow gradient
        gradientColors = List.generate(
          6,
          (i) => HSVColor.fromAHSV(1.0, (hue + i * 60) % 360, 1.0, 1.0).toColor(),
        );
        break;
    }

    Widget textWidget;

    // Use appropriate renderer based on text style
    switch (_textStyle) {
      case TextDisplayStyle.ledMatrix:
        textWidget = LEDMatrixText(
          text: _message,
          primaryColor: primaryColor,
          gradientColors: gradientColors,
          config: _ledConfig,
          animate: false,
        );
        break;

      case TextDisplayStyle.neon:
        textWidget = NeonGlowText(
          text: _message,
          primaryColor: primaryColor,
          glowColor: _neonConfig.glowColor ?? primaryColor,
          gradientColors: gradientColors,
          fontSize: _fontSize,
          intensity: _neonConfig.intensity.multiplier,
          flickerMode: _neonConfig.flickerMode,
          pulseGlow: _neonConfig.pulseGlow,
        );
        break;

      case TextDisplayStyle.sevenSegment:
        textWidget = SevenSegmentText(
          text: _message,
          primaryColor: primaryColor,
          gradientColors: gradientColors,
          config: _sevenSegmentConfig,
          animate: false,
        );
        break;

      case TextDisplayStyle.pixel:
        textWidget = PixelRetroText(
          text: _message,
          primaryColor: primaryColor,
          gradientColors: gradientColors,
          config: _pixelConfig,
          animate: false,
        );
        break;

      case TextDisplayStyle.stadium:
        textWidget = StadiumBulbText(
          text: _message,
          primaryColor: primaryColor,
          gradientColors: gradientColors,
          config: _stadiumConfig,
          animate: false,
        );
        break;

      case TextDisplayStyle.normal:
        // Normal text rendering
        textWidget = Text(
          _message,
          style: TextStyle(
            fontSize: _fontSize,
            fontWeight: _fontWeight,
            color: _colorMode == ColorMode.solid ? _solidColor : null,
            foreground: _colorMode == ColorMode.gradient
                ? (Paint()
                  ..shader = LinearGradient(
                    colors: _gradientColors,
                  ).createShader(const Rect.fromLTWH(0, 0, 500, 100)))
                : null,
          ),
          textAlign: TextAlign.center,
        );
        break;
    }

    // Apply effects (only for normal text style - LED/Neon have their own effects)
    if (_textStyle == TextDisplayStyle.normal) {
      if (_effectMode == EffectMode.pulse) {
        textWidget = _PulseEffect(child: textWidget);
      } else if (_effectMode == EffectMode.sparkle) {
        textWidget = _SparkleEffect(child: textWidget);
      }
    }

    // Apply scrolling
    if (_isFullscreen) {
      return SlideTransition(
        position: _scrollAnimation,
        child: textWidget,
      );
    }

    return textWidget;
  }

  Color _getBackgroundColor() {
    if (_colorMode == ColorMode.rainbow) {
      // Animated rainbow background
      return HSVColor.fromAHSV(
        1.0,
        (_scrollController.value * 360) % 360,
        0.3,
        0.2,
      ).toColor();
    }
    if (_useCustomBackground) {
      return _backgroundColor;
    }
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: _getBackgroundColor(),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _showControls = !_showControls;
            });
          },
          child: Stack(
            children: [
              // Fullscreen scrolling text
              Center(
                child: _buildTextDisplay(),
              ),

              // Exit button (top-right)
              if (_showControls)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 32),
                    onPressed: _exitFullscreen,
                  ),
                ),

              // Quick controls (bottom)
              if (_showControls)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _beatSyncEnabled ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: () {
                                setState(() {
                                  _beatSyncEnabled = !_beatSyncEnabled;
                                  if (_beatSyncEnabled) {
                                    _startBeatSync();
                                  } else {
                                    _stopBeatSync();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        // Beat sensitivity slider (only when beat sync is enabled)
                        if (_beatSyncEnabled) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.volume_down, color: Colors.white70, size: 20),
                              Expanded(
                                child: Slider(
                                  value: _beatSensitivity,
                                  min: 0.0,
                                  max: 1.0,
                                  divisions: 20,
                                  activeColor: Colors.white,
                                  inactiveColor: Colors.white30,
                                  onChanged: (value) {
                                    setState(() {
                                      _beatSensitivity = value;
                                    });
                                    _beatDetector.sensitivity = value;
                                    _saveSettings();
                                  },
                                ),
                              ),
                              const Icon(Icons.volume_up, color: Colors.white70, size: 20),
                            ],
                          ),
                          Text(
                            _beatSensitivity < 0.33 ? 'Low Sensitivity'
                                : _beatSensitivity < 0.67 ? 'Medium Sensitivity'
                                : 'High Sensitivity',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Setup screen - "Backstage to Spotlight" aesthetic
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
          ).createShader(bounds),
          child: const Text(
            'CONCERT MODE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.white70),
            onPressed: _showCustomizationSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Animated gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A0A0F),
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0A0A0F),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // Spotlight glow effects
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _solidColor.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -50,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (_gradientColors.isNotEmpty ? _gradientColors.last : Colors.purple)
                        .withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),

                  // Stage Preview - The main attraction
                  _buildStagePreview(screenSize),

                  const SizedBox(height: 24),

                  // Message input with glass effect
                  _buildGlassMessageInput(),

                  const SizedBox(height: 20),

                  // Quick Style Selector
                  _buildQuickStyleSelector(),

                  const SizedBox(height: 20),

                  // Quick Color Chips
                  _buildQuickColorChips(),

                  const SizedBox(height: 16),

                  // Action buttons row
                  Row(
                    children: [
                      Expanded(
                        child: _buildGlassButton(
                          icon: Icons.auto_awesome,
                          label: 'Templates',
                          onTap: _showTemplateLibrary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGlassButton(
                          icon: Icons.settings,
                          label: 'Advanced',
                          onTap: _showCustomizationSheet,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // GO LIVE Button - The star of the show
                  _buildGoLiveButton(),

                  const SizedBox(height: 24),

                  // Quick tips with subtle styling
                  _buildQuickTips(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStagePreview(Size screenSize) {
    return Container(
      height: screenSize.height * 0.28,
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _solidColor.withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: -10,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Stage curtain effect (top edge)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                gradient: LinearGradient(
                  colors: [
                    _solidColor.withValues(alpha: 0.8),
                    _solidColor.withValues(alpha: 0.4),
                    _solidColor.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),

          // The text display
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildTextDisplay(),
              ),
            ),
          ),

          // "PREVIEW" badge
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B6B),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'PREVIEW',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassMessageInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: TextField(
        controller: _messageController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Type your message...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
          ),
          prefixIcon: Icon(
            Icons.edit,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          suffixIcon: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _solidColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check,
                color: _solidColor,
                size: 18,
              ),
            ),
            onPressed: () {
              setState(() {
                _message = _messageController.text;
              });
              _saveSettings();
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onSubmitted: (value) {
          setState(() {
            _message = value;
          });
          _saveSettings();
        },
      ),
    );
  }

  Widget _buildQuickStyleSelector() {
    final styles = [
      (TextDisplayStyle.normal, 'ABC', 'Normal'),
      (TextDisplayStyle.ledMatrix, '●●●', 'LED'),
      (TextDisplayStyle.neon, '✦', 'Neon'),
      (TextDisplayStyle.sevenSegment, '888', '7-Seg'),
      (TextDisplayStyle.pixel, '▓▓', 'Pixel'),
      (TextDisplayStyle.stadium, '◉', 'Bulb'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'STYLE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: styles.map((style) {
              final isSelected = _textStyle == style.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _textStyle = style.$1;
                    });
                    _saveSettings();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _solidColor.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _solidColor.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _solidColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: -2,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          style.$2,
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected ? _solidColor : Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          style.$3,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickColorChips() {
    final colors = [
      Colors.white,
      const Color(0xFFFF6B6B),
      const Color(0xFFFFE66D),
      const Color(0xFF4ECDC4),
      const Color(0xFF45B7D1),
      const Color(0xFFA855F7),
      const Color(0xFFFF69B4),
      const Color(0xFF22C55E),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                'COLOR',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showTextColorPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.colorize,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Custom',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: colors.map((color) {
            final isSelected = _solidColor.toARGB32() == color.toARGB32();
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _solidColor = color;
                    _colorMode = ColorMode.solid;
                  });
                  _saveSettings();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: color.computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoLiveButton() {
    // Calculate text color based on button background luminance
    // Use a lower threshold for better contrast
    final buttonLuminance = _solidColor.computeLuminance();
    final textColor = buttonLuminance > 0.4 ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: _enterFullscreen,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              _solidColor,
              Color.lerp(_solidColor, Colors.white, 0.15)!,
              _solidColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _solidColor.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: _solidColor.withValues(alpha: 0.3),
              blurRadius: 40,
              spreadRadius: -8,
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                color: textColor,
                size: 32,
              ),
              const SizedBox(width: 8),
              Text(
                'GO LIVE',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.amber.withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap anywhere during concert mode to show controls',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Template Library Bottom Sheet
class _TemplateLibrarySheet extends StatelessWidget {
  final List<MessageTemplate> templates;
  final List<MessageTemplate> favorites;
  final Function(MessageTemplate) onSelectTemplate;
  final Function(MessageTemplate, bool) onToggleFavorite;

  const _TemplateLibrarySheet({
    required this.templates,
    required this.favorites,
    required this.onSelectTemplate,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Templates',
                  style: theme.textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(),

          // Favorites section
          if (favorites.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Favorites',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final template = favorites[index];
                  return _TemplateCard(
                    template: template,
                    isFavorite: true,
                    onTap: () => onSelectTemplate(template),
                    onToggleFavorite: (isFav) =>
                        onToggleFavorite(template, isFav),
                  );
                },
              ),
            ),
            const Divider(),
          ],

          // All templates
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                final isFavorite =
                    favorites.any((f) => f.text == template.text);
                return _TemplateCard(
                  template: template,
                  isFavorite: isFavorite,
                  onTap: () => onSelectTemplate(template),
                  onToggleFavorite: (isFav) => onToggleFavorite(template, isFav),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Template Card Widget
class _TemplateCard extends StatelessWidget {
  final MessageTemplate template;
  final bool isFavorite;
  final VoidCallback onTap;
  final Function(bool) onToggleFavorite;

  const _TemplateCard({
    required this.template,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: template.gradientColors.length > 1
              ? LinearGradient(colors: template.gradientColors)
              : null,
          color: template.gradientColors.length == 1
              ? template.solidColor
              : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                template.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 20,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 4),
                  ],
                ),
                onPressed: () => onToggleFavorite(!isFavorite),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Customization Bottom Sheet - Dark Stage Aesthetic
class _CustomizationSheet extends StatelessWidget {
  final ScrollDirection scrollDirection;
  final double scrollSpeed;
  final double fontSize;
  final FontWeight fontWeight;
  final ColorMode colorMode;
  final Color solidColor;
  final List<Color> gradientColors;
  final Color backgroundColor;
  final bool useCustomBackground;
  final EffectMode effectMode;
  final TextDisplayStyle textStyle;
  final LEDMatrixConfig ledConfig;
  final NeonGlowConfig neonConfig;
  final SevenSegmentConfig sevenSegmentConfig;
  final PixelRetroConfig pixelConfig;
  final StadiumBulbConfig stadiumConfig;
  final bool beatSyncEnabled;
  final double strobeFrequency;
  final double beatSensitivity;
  final ScreenOrientation screenOrientation;
  final VoidCallback onShowTextColorPicker;
  final VoidCallback onShowBackgroundColorPicker;
  final Function(ScrollDirection) onScrollDirectionChanged;
  final Function(double) onScrollSpeedChanged;
  final Function(double) onFontSizeChanged;
  final Function(FontWeight) onFontWeightChanged;
  final Function(ColorMode) onColorModeChanged;
  final Function(Color) onSolidColorChanged;
  final Function(List<Color>) onGradientColorsChanged;
  final Function(bool) onUseCustomBackgroundChanged;
  final Function(EffectMode) onEffectModeChanged;
  final Function(TextDisplayStyle) onTextStyleChanged;
  final Function(LEDMatrixConfig) onLedConfigChanged;
  final Function(NeonGlowConfig) onNeonConfigChanged;
  final Function(SevenSegmentConfig) onSevenSegmentConfigChanged;
  final Function(PixelRetroConfig) onPixelConfigChanged;
  final Function(StadiumBulbConfig) onStadiumConfigChanged;
  final Function(bool) onBeatSyncChanged;
  final Function(double) onStrobeFrequencyChanged;
  final Function(double) onBeatSensitivityChanged;
  final Function(ScreenOrientation) onScreenOrientationChanged;

  const _CustomizationSheet({
    required this.scrollDirection,
    required this.scrollSpeed,
    required this.fontSize,
    required this.fontWeight,
    required this.colorMode,
    required this.solidColor,
    required this.gradientColors,
    required this.backgroundColor,
    required this.useCustomBackground,
    required this.effectMode,
    required this.textStyle,
    required this.ledConfig,
    required this.neonConfig,
    required this.sevenSegmentConfig,
    required this.pixelConfig,
    required this.stadiumConfig,
    required this.beatSyncEnabled,
    required this.strobeFrequency,
    required this.beatSensitivity,
    required this.screenOrientation,
    required this.onShowTextColorPicker,
    required this.onShowBackgroundColorPicker,
    required this.onScrollDirectionChanged,
    required this.onScrollSpeedChanged,
    required this.onFontSizeChanged,
    required this.onFontWeightChanged,
    required this.onColorModeChanged,
    required this.onSolidColorChanged,
    required this.onGradientColorsChanged,
    required this.onUseCustomBackgroundChanged,
    required this.onEffectModeChanged,
    required this.onTextStyleChanged,
    required this.onLedConfigChanged,
    required this.onNeonConfigChanged,
    required this.onSevenSegmentConfigChanged,
    required this.onPixelConfigChanged,
    required this.onStadiumConfigChanged,
    required this.onBeatSyncChanged,
    required this.onStrobeFrequencyChanged,
    required this.onBeatSensitivityChanged,
    required this.onScreenOrientationChanged,
  });

  // Accent color based on current solid color
  Color get _accentColor => solidColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF0F0F1A),
            Color(0xFF0A0A0F),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with title and close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: _accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fine-tune',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Advanced settings',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ═══════════════════════════════════════════
                // DISPLAY SECTION
                // ═══════════════════════════════════════════
                _buildSectionHeader(
                  icon: Icons.display_settings_rounded,
                  title: 'DISPLAY',
                  subtitle: 'Screen & scroll behavior',
                ),
                const SizedBox(height: 12),
                _buildGlassCard(
                  children: [
                    // Screen Orientation
                    _buildOptionLabel('Screen Orientation'),
                    const SizedBox(height: 8),
                    _buildSegmentedSelector<ScreenOrientation>(
                      options: ScreenOrientation.values,
                      selected: screenOrientation,
                      labelBuilder: (o) => o == ScreenOrientation.auto
                          ? 'Auto'
                          : o == ScreenOrientation.portrait
                              ? 'Portrait'
                              : 'Landscape',
                      iconBuilder: (o) => o == ScreenOrientation.auto
                          ? Icons.screen_rotation_rounded
                          : o == ScreenOrientation.portrait
                              ? Icons.stay_current_portrait_rounded
                              : Icons.stay_current_landscape_rounded,
                      onSelected: onScreenOrientationChanged,
                    ),
                    const SizedBox(height: 20),

                    // Scroll Direction
                    _buildOptionLabel('Scroll Direction'),
                    const SizedBox(height: 8),
                    _buildSegmentedSelector<ScrollDirection>(
                      options: ScrollDirection.values,
                      selected: scrollDirection,
                      labelBuilder: (d) => d == ScrollDirection.horizontal
                          ? 'Horizontal'
                          : 'Vertical',
                      iconBuilder: (d) => d == ScrollDirection.horizontal
                          ? Icons.swap_horiz_rounded
                          : Icons.swap_vert_rounded,
                      onSelected: onScrollDirectionChanged,
                    ),
                    const SizedBox(height: 20),

                    // Scroll Speed
                    _buildSliderOption(
                      label: 'Scroll Speed',
                      value: scrollSpeed,
                      min: 0.5,
                      max: 3.0,
                      divisions: 10,
                      valueLabel: '${scrollSpeed.toStringAsFixed(1)}x',
                      onChanged: onScrollSpeedChanged,
                    ),
                    const SizedBox(height: 16),

                    // Font Size
                    _buildSliderOption(
                      label: 'Text Size',
                      value: fontSize,
                      min: 36,
                      max: 144,
                      divisions: 18,
                      valueLabel: '${fontSize.toInt()}pt',
                      onChanged: onFontSizeChanged,
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ═══════════════════════════════════════════
                // STYLE OPTIONS SECTION (Contextual)
                // ═══════════════════════════════════════════
                if (textStyle != TextDisplayStyle.normal) ...[
                  _buildSectionHeader(
                    icon: _getStyleIcon(textStyle),
                    title: '${_getStyleName(textStyle).toUpperCase()} OPTIONS',
                    subtitle: 'Fine-tune ${_getStyleName(textStyle)} appearance',
                  ),
                  const SizedBox(height: 12),
                  _buildStyleOptionsCard(),
                  const SizedBox(height: 28),
                ],

                // ═══════════════════════════════════════════
                // COLORS SECTION
                // ═══════════════════════════════════════════
                _buildSectionHeader(
                  icon: Icons.palette_rounded,
                  title: 'COLORS',
                  subtitle: 'Advanced color modes',
                ),
                const SizedBox(height: 12),
                _buildGlassCard(
                  children: [
                    // Color Mode selector
                    _buildOptionLabel('Color Mode'),
                    const SizedBox(height: 10),
                    Row(
                      children: ColorMode.values.map((mode) {
                        final isSelected = colorMode == mode;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onColorModeChanged(mode),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(
                                right: mode != ColorMode.values.last ? 8 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _accentColor.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? _accentColor.withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    mode == ColorMode.solid
                                        ? Icons.circle
                                        : mode == ColorMode.gradient
                                            ? Icons.gradient_rounded
                                            : Icons.auto_awesome_rounded,
                                    color: isSelected
                                        ? _accentColor
                                        : Colors.white54,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mode == ColorMode.solid
                                        ? 'Solid'
                                        : mode == ColorMode.gradient
                                            ? 'Gradient'
                                            : 'Rainbow',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white54,
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // Color picker button for solid mode
                    if (colorMode == ColorMode.solid) ...[
                      const SizedBox(height: 16),
                      _buildColorPickerRow(
                        label: 'Text Color',
                        color: solidColor,
                        onTap: () {
                          Navigator.of(context).pop();
                          Future.delayed(const Duration(milliseconds: 100), () {
                            onShowTextColorPicker();
                          });
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Background toggle
                    _buildToggleOption(
                      icon: Icons.format_color_fill_rounded,
                      title: 'Custom Background',
                      subtitle: 'Use color instead of black',
                      value: useCustomBackground,
                      onChanged: onUseCustomBackgroundChanged,
                    ),

                    if (useCustomBackground) ...[
                      const SizedBox(height: 12),
                      _buildColorPickerRow(
                        label: 'Background',
                        color: backgroundColor,
                        onTap: () {
                          Navigator.of(context).pop();
                          Future.delayed(const Duration(milliseconds: 100), () {
                            onShowBackgroundColorPicker();
                          });
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 28),

                // ═══════════════════════════════════════════
                // EFFECTS SECTION
                // ═══════════════════════════════════════════
                _buildSectionHeader(
                  icon: Icons.auto_fix_high_rounded,
                  title: 'EFFECTS',
                  subtitle: 'Visual animations',
                ),
                const SizedBox(height: 12),
                _buildGlassCard(
                  children: [
                    _buildOptionLabel('Animation Effect'),
                    const SizedBox(height: 10),
                    Row(
                      children: EffectMode.values.map((mode) {
                        final isSelected = effectMode == mode;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onEffectModeChanged(mode),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: EdgeInsets.only(
                                right: mode != EffectMode.values.last ? 8 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _accentColor.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? _accentColor.withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    mode == EffectMode.none
                                        ? Icons.block_rounded
                                        : mode == EffectMode.pulse
                                            ? Icons.favorite_rounded
                                            : Icons.auto_awesome,
                                    color: isSelected
                                        ? _accentColor
                                        : Colors.white54,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mode == EffectMode.none
                                        ? 'None'
                                        : mode == EffectMode.pulse
                                            ? 'Pulse'
                                            : 'Sparkle',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white54,
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ═══════════════════════════════════════════
                // AUDIO SYNC SECTION
                // ═══════════════════════════════════════════
                _buildSectionHeader(
                  icon: Icons.music_note_rounded,
                  title: 'AUDIO SYNC',
                  subtitle: 'Beat detection & strobe',
                ),
                const SizedBox(height: 12),
                _buildGlassCard(
                  children: [
                    _buildToggleOption(
                      icon: Icons.flash_on_rounded,
                      title: 'Beat Sync Strobe',
                      subtitle: 'Flash to music rhythm',
                      value: beatSyncEnabled,
                      onChanged: onBeatSyncChanged,
                    ),

                    if (beatSyncEnabled) ...[
                      const SizedBox(height: 20),
                      _buildSliderOption(
                        label: 'Beat Sensitivity',
                        value: beatSensitivity,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        valueLabel: beatSensitivity < 0.33
                            ? 'Low'
                            : beatSensitivity < 0.67
                                ? 'Medium'
                                : 'High',
                        onChanged: onBeatSensitivityChanged,
                        helperText: 'Higher = detects quieter beats',
                      ),
                      const SizedBox(height: 16),
                      _buildSliderOption(
                        label: 'Max Strobe Rate',
                        value: strobeFrequency,
                        min: 0.5,
                        max: 10.0,
                        divisions: 19,
                        valueLabel: '${strobeFrequency.toStringAsFixed(1)} Hz',
                        onChanged: onStrobeFrequencyChanged,
                        helperText: 'Safety limit for flash speed',
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _accentColor, size: 16),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildOptionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildSegmentedSelector<T>({
    required List<T> options,
    required T selected,
    required String Function(T) labelBuilder,
    required IconData Function(T) iconBuilder,
    required Function(T) onSelected,
  }) {
    return Row(
      children: options.map((option) {
        final isSelected = selected == option;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                right: option != options.last ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? _accentColor.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? _accentColor.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    iconBuilder(option),
                    color: isSelected ? _accentColor : Colors.white54,
                    size: 18,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labelBuilder(option),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSliderOption({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required Function(double) onChanged,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                valueLabel,
                style: TextStyle(
                  color: _accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (helperText != null) ...[
          const SizedBox(height: 2),
          Text(
            helperText,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _accentColor,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: _accentColor,
            overlayColor: _accentColor.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value
                  ? _accentColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? _accentColor : Colors.white54,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _accentColor,
            activeTrackColor: _accentColor.withValues(alpha: 0.3),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            inactiveThumbColor: Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerRow({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: -2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.colorize_rounded,
                    color: _accentColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Pick',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Style-specific helper methods
  IconData _getStyleIcon(TextDisplayStyle style) {
    switch (style) {
      case TextDisplayStyle.ledMatrix:
        return Icons.grid_view_rounded;
      case TextDisplayStyle.neon:
        return Icons.blur_on_rounded;
      case TextDisplayStyle.sevenSegment:
        return Icons.segment_rounded;
      case TextDisplayStyle.pixel:
        return Icons.view_comfy_rounded;
      case TextDisplayStyle.stadium:
        return Icons.stadium_rounded;
      case TextDisplayStyle.normal:
        return Icons.text_fields_rounded;
    }
  }

  String _getStyleName(TextDisplayStyle style) {
    switch (style) {
      case TextDisplayStyle.ledMatrix:
        return 'LED';
      case TextDisplayStyle.neon:
        return 'Neon';
      case TextDisplayStyle.sevenSegment:
        return '7-Segment';
      case TextDisplayStyle.pixel:
        return 'Pixel';
      case TextDisplayStyle.stadium:
        return 'Bulb';
      case TextDisplayStyle.normal:
        return 'Normal';
    }
  }

  Widget _buildStyleOptionsCard() {
    switch (textStyle) {
      case TextDisplayStyle.ledMatrix:
        return _buildLEDOptionsCard();
      case TextDisplayStyle.neon:
        return _buildNeonOptionsCard();
      case TextDisplayStyle.sevenSegment:
        return _buildSevenSegmentOptionsCard();
      case TextDisplayStyle.pixel:
        return _buildPixelOptionsCard();
      case TextDisplayStyle.stadium:
        return _buildStadiumOptionsCard();
      case TextDisplayStyle.normal:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLEDOptionsCard() {
    return _buildGlassCard(
      children: [
        // Dot Size
        _buildOptionLabel('Dot Size'),
        const SizedBox(height: 8),
        _buildSegmentedSelector<LEDDotSize>(
          options: LEDDotSize.values,
          selected: ledConfig.dotSize,
          labelBuilder: (s) => s.displayName,
          iconBuilder: (_) => Icons.circle,
          onSelected: (size) =>
              onLedConfigChanged(ledConfig.copyWith(dotSize: size)),
        ),
        const SizedBox(height: 16),

        // Dot Shape
        _buildOptionLabel('Dot Shape'),
        const SizedBox(height: 8),
        _buildSegmentedSelector<LEDDotShape>(
          options: LEDDotShape.values,
          selected: ledConfig.dotShape,
          labelBuilder: (s) => s.displayName,
          iconBuilder: (s) => s == LEDDotShape.circle
              ? Icons.circle
              : s == LEDDotShape.square
                  ? Icons.square
                  : Icons.rounded_corner,
          onSelected: (shape) =>
              onLedConfigChanged(ledConfig.copyWith(dotShape: shape)),
        ),
        const SizedBox(height: 16),

        // Unlit Opacity
        _buildSliderOption(
          label: 'Unlit Dots Opacity',
          value: ledConfig.unlitOpacity,
          min: 0.0,
          max: 0.3,
          divisions: 6,
          valueLabel: '${(ledConfig.unlitOpacity * 100).toInt()}%',
          onChanged: (v) =>
              onLedConfigChanged(ledConfig.copyWith(unlitOpacity: v)),
        ),
        const SizedBox(height: 12),

        // Emoji Colors toggle
        _buildToggleOption(
          icon: Icons.emoji_emotions_rounded,
          title: 'Emoji Colors',
          subtitle: 'Show emojis in natural colors',
          value: ledConfig.useEmojiColors,
          onChanged: (v) =>
              onLedConfigChanged(ledConfig.copyWith(useEmojiColors: v)),
        ),
      ],
    );
  }

  Widget _buildNeonOptionsCard() {
    return _buildGlassCard(
      children: [
        // Glow Intensity
        _buildOptionLabel('Glow Intensity'),
        const SizedBox(height: 8),
        _buildSegmentedSelector<NeonGlowIntensity>(
          options: NeonGlowIntensity.values,
          selected: neonConfig.intensity,
          labelBuilder: (i) => i.displayName,
          iconBuilder: (_) => Icons.blur_on_rounded,
          onSelected: (intensity) =>
              onNeonConfigChanged(neonConfig.copyWith(intensity: intensity)),
        ),
        const SizedBox(height: 16),

        // Flicker Mode
        _buildOptionLabel('Flicker Effect'),
        const SizedBox(height: 8),
        _buildSegmentedSelector<NeonFlickerMode>(
          options: NeonFlickerMode.values,
          selected: neonConfig.flickerMode,
          labelBuilder: (m) => m.displayName,
          iconBuilder: (_) => Icons.flash_on_rounded,
          onSelected: (mode) =>
              onNeonConfigChanged(neonConfig.copyWith(flickerMode: mode)),
        ),
        const SizedBox(height: 16),

        // Pulse Glow toggle
        _buildToggleOption(
          icon: Icons.favorite_rounded,
          title: 'Pulse Glow',
          subtitle: 'Breathing glow animation',
          value: neonConfig.pulseGlow,
          onChanged: (v) =>
              onNeonConfigChanged(neonConfig.copyWith(pulseGlow: v)),
        ),
      ],
    );
  }

  Widget _buildSevenSegmentOptionsCard() {
    return _buildGlassCard(
      children: [
        // Segment Style
        _buildOptionLabel('Segment Style'),
        const SizedBox(height: 8),
        _buildSegmentedSelector<SegmentStyle>(
          options: SegmentStyle.values,
          selected: sevenSegmentConfig.style,
          labelBuilder: (s) => s.displayName,
          iconBuilder: (_) => Icons.segment_rounded,
          onSelected: (style) => onSevenSegmentConfigChanged(
              sevenSegmentConfig.copyWith(style: style)),
        ),
        const SizedBox(height: 16),

        // Segment Thickness
        _buildOptionLabel('Segment Thickness'),
        const SizedBox(height: 8),
        _buildSegmentedSelector<SegmentThickness>(
          options: SegmentThickness.values,
          selected: sevenSegmentConfig.thickness,
          labelBuilder: (t) => t.displayName,
          iconBuilder: (_) => Icons.line_weight_rounded,
          onSelected: (thickness) => onSevenSegmentConfigChanged(
              sevenSegmentConfig.copyWith(thickness: thickness)),
        ),
        const SizedBox(height: 16),

        // Off-Segment Opacity
        _buildSliderOption(
          label: 'Off-Segment Opacity',
          value: sevenSegmentConfig.offSegmentOpacity,
          min: 0.0,
          max: 0.3,
          divisions: 6,
          valueLabel: '${(sevenSegmentConfig.offSegmentOpacity * 100).toInt()}%',
          onChanged: (v) => onSevenSegmentConfigChanged(
              sevenSegmentConfig.copyWith(offSegmentOpacity: v)),
        ),
      ],
    );
  }

  Widget _buildPixelOptionsCard() {
    return _buildGlassCard(
      children: [
        // Pixel Size
        _buildOptionLabel('Pixel Size'),
        const SizedBox(height: 8),
        _buildSegmentedSelector<PixelSize>(
          options: PixelSize.values,
          selected: pixelConfig.pixelSize,
          labelBuilder: (s) => s.displayName,
          iconBuilder: (_) => Icons.grid_4x4_rounded,
          onSelected: (size) =>
              onPixelConfigChanged(pixelConfig.copyWith(pixelSize: size)),
        ),
        const SizedBox(height: 16),

        // Scanlines toggle
        _buildToggleOption(
          icon: Icons.gradient_rounded,
          title: 'Scanlines',
          subtitle: 'CRT-style horizontal lines',
          value: pixelConfig.showScanlines,
          onChanged: (v) =>
              onPixelConfigChanged(pixelConfig.copyWith(showScanlines: v)),
        ),

        if (pixelConfig.showScanlines) ...[
          const SizedBox(height: 12),
          _buildSliderOption(
            label: 'Scanline Intensity',
            value: pixelConfig.scanlineOpacity,
            min: 0.1,
            max: 0.6,
            divisions: 5,
            valueLabel: '${(pixelConfig.scanlineOpacity * 100).toInt()}%',
            onChanged: (v) =>
                onPixelConfigChanged(pixelConfig.copyWith(scanlineOpacity: v)),
          ),
        ],
        const SizedBox(height: 12),

        // CRT Curve toggle
        _buildToggleOption(
          icon: Icons.tv_rounded,
          title: 'CRT Curve Effect',
          subtitle: 'Vignette at edges',
          value: pixelConfig.showCrtCurve,
          onChanged: (v) =>
              onPixelConfigChanged(pixelConfig.copyWith(showCrtCurve: v)),
        ),
        const SizedBox(height: 12),

        // Chroma Shift toggle
        _buildToggleOption(
          icon: Icons.blur_linear_rounded,
          title: 'Chroma Shift',
          subtitle: 'RGB color separation effect',
          value: pixelConfig.chromaShift,
          onChanged: (v) =>
              onPixelConfigChanged(pixelConfig.copyWith(chromaShift: v)),
        ),
      ],
    );
  }

  Widget _buildStadiumOptionsCard() {
    return _buildGlassCard(
      children: [
        // Bulb Size
        _buildOptionLabel('Bulb Size'),
        const SizedBox(height: 8),
        _buildSegmentedSelector<BulbSize>(
          options: BulbSize.values,
          selected: stadiumConfig.bulbSize,
          labelBuilder: (s) => s.displayName,
          iconBuilder: (_) => Icons.lightbulb_rounded,
          onSelected: (size) =>
              onStadiumConfigChanged(stadiumConfig.copyWith(bulbSize: size)),
        ),
        const SizedBox(height: 16),

        // Bulb Spacing
        _buildOptionLabel('Bulb Spacing'),
        const SizedBox(height: 8),
        _buildSegmentedSelector<BulbSpacing>(
          options: BulbSpacing.values,
          selected: stadiumConfig.bulbSpacing,
          labelBuilder: (s) => s.displayName,
          iconBuilder: (_) => Icons.space_bar_rounded,
          onSelected: (spacing) => onStadiumConfigChanged(
              stadiumConfig.copyWith(bulbSpacing: spacing)),
        ),
        const SizedBox(height: 16),

        // Show Sockets toggle
        _buildToggleOption(
          icon: Icons.radio_button_checked_rounded,
          title: 'Show Sockets',
          subtitle: 'Metallic rings around bulbs',
          value: stadiumConfig.showSocket,
          onChanged: (v) =>
              onStadiumConfigChanged(stadiumConfig.copyWith(showSocket: v)),
        ),
        const SizedBox(height: 12),

        // Warm Tint toggle
        _buildToggleOption(
          icon: Icons.wb_incandescent_rounded,
          title: 'Warm Tint',
          subtitle: 'Incandescent color warmth',
          value: stadiumConfig.warmTint,
          onChanged: (v) =>
              onStadiumConfigChanged(stadiumConfig.copyWith(warmTint: v)),
        ),
        const SizedBox(height: 12),

        // Show Glow toggle
        _buildToggleOption(
          icon: Icons.flare_rounded,
          title: 'Show Glow',
          subtitle: 'Soft light around bulbs',
          value: stadiumConfig.showGlow,
          onChanged: (v) =>
              onStadiumConfigChanged(stadiumConfig.copyWith(showGlow: v)),
        ),

        if (stadiumConfig.showGlow) ...[
          const SizedBox(height: 12),
          _buildSliderOption(
            label: 'Glow Intensity',
            value: stadiumConfig.glowIntensity,
            min: 0.2,
            max: 1.0,
            divisions: 8,
            valueLabel: '${(stadiumConfig.glowIntensity * 100).toInt()}%',
            onChanged: (v) => onStadiumConfigChanged(
                stadiumConfig.copyWith(glowIntensity: v)),
          ),
        ],
        const SizedBox(height: 12),

        // Unlit Opacity
        _buildSliderOption(
          label: 'Unlit Bulb Opacity',
          value: stadiumConfig.unlitOpacity,
          min: 0.0,
          max: 0.3,
          divisions: 6,
          valueLabel: '${(stadiumConfig.unlitOpacity * 100).toInt()}%',
          onChanged: (v) =>
              onStadiumConfigChanged(stadiumConfig.copyWith(unlitOpacity: v)),
        ),
      ],
    );
  }
}

// Pulse Effect Widget
class _PulseEffect extends StatefulWidget {
  final Widget child;

  const _PulseEffect({required this.child});

  @override
  State<_PulseEffect> createState() => _PulseEffectState();
}

class _PulseEffectState extends State<_PulseEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

// Sparkle Effect Widget
class _SparkleEffect extends StatefulWidget {
  final Widget child;

  const _SparkleEffect({required this.child});

  @override
  State<_SparkleEffect> createState() => _SparkleEffectState();
}

class _SparkleEffectState extends State<_SparkleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
              colors: const [
                Colors.transparent,
                Colors.white,
                Colors.transparent,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// Data models
class MessageTemplate {
  final String text;
  final Color solidColor;
  final List<Color> gradientColors;

  MessageTemplate(this.text, this.solidColor, this.gradientColors);

  Map<String, dynamic> toJson() => {
        'text': text,
        'solidColor': solidColor.toARGB32(),
        'gradientColors': gradientColors.map((c) => c.toARGB32()).toList(),
      };

  factory MessageTemplate.fromJson(Map<String, dynamic> json) {
    final solidColorValue = json['solidColor'] as int;
    final gradientColorValues = json['gradientColors'] as List;

    return MessageTemplate(
      json['text'] as String,
      Color((solidColorValue & 0xFF000000) |
            ((solidColorValue >> 16) & 0xFF) |
            (solidColorValue & 0x0000FF00) |
            ((solidColorValue & 0xFF) << 16)),
      gradientColorValues.map((c) {
        final value = c as int;
        return Color((value & 0xFF000000) |
                    ((value >> 16) & 0xFF) |
                    (value & 0x0000FF00) |
                    ((value & 0xFF) << 16));
      }).toList(),
    );
  }
}

enum ScrollDirection { horizontal, vertical }

enum ColorMode { solid, gradient, rainbow }

enum EffectMode { none, pulse, sparkle }

enum ScreenOrientation {
  auto('Auto'),
  portrait('Portrait'),
  landscape('Landscape');

  final String label;
  const ScreenOrientation(this.label);
}
