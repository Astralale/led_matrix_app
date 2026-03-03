import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/constants.dart';
import '../services/text_mode_controller.dart';
import 'camera_mode_screen.dart';
import 'settings_screen.dart';
import 'text_mode_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final TextModeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextModeController();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSettingsChanged({
    String? emergencyMessage,
    int? scrollSpeedMs,
    int? blinkIntervalMs,
    int? brightness,
  }) {
    _controller.updateSettings(
      emergencyMessage: emergencyMessage,
      scrollSpeedMs: scrollSpeedMs,
      blinkIntervalMs: blinkIntervalMs,
      brightness: brightness,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          TextModeScreen(controller: _controller),
          const CameraModeScreen(),
          SettingsScreen(onSettingsChanged: _onSettingsChanged),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppConstants.borderColor, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppConstants.backgroundColor,
          selectedItemColor: AppConstants.accentColor,
          unselectedItemColor: AppConstants.accentColor.withValues(alpha: 0.35),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.text_fields),
              activeIcon: Icon(Icons.text_fields),
              label: 'Texte',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt_outlined),
              activeIcon: Icon(Icons.camera_alt),
              label: 'Caméra',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Paramètres',
            ),
          ],
        ),
      ),
    );
  }
}
