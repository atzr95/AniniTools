import 'package:flutter/material.dart';
import 'package:aninitools/models/prefs.dart';
import 'flashlight/flashlight_screen.dart';
import 'sensors/sensor_screen.dart';
import 'compass/compass_screen.dart';

/// Main home screen with bottom navigation
/// Follows "Flashlight-First" design pattern from product strategy
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    // Start with flashlight screen (index 0) for immediate utility
    // Can restore last tab if user wants continuity
    _currentIndex = Prefs().lastSelectedTab;
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      Prefs().lastSelectedTab = index;
    });
  }

  /// Build the currently selected screen
  /// This ensures only the active screen is kept in memory
  /// and sensors are stopped when navigating away
  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return const FlashlightScreen();
      case 1:
        return const SensorScreen();
      case 2:
        return const CompassScreen();
      default:
        return const FlashlightScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCurrentScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flashlight_on_outlined),
            selectedIcon: Icon(Icons.flashlight_on),
            label: 'Flash',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors),
            label: 'Sensors',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Compass',
          ),
        ],
      ),
    );
  }
}
