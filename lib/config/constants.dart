import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const int matrixWidth = 32;
  static const int matrixHeight = 16;
  static const int totalLeds = matrixWidth * matrixHeight;

  static const List<Color> colorPalette = [
    Color(0xFF000000), // 0  - Off
    // Rouges / roses
    Color(0xFFFF0000), // 1
    Color(0xFFFF1744), // 2
    Color(0xFFD50000), // 3
    Color(0xFFFF5252), // 4
    Color(0xFFFF4081), // 5
    Color(0xFFF50057), // 6
    Color(0xFFC51162), // 7
    // Oranges / jaunes
    Color(0xFFFF6D00), // 8
    Color(0xFFFF8F00), // 9
    Color(0xFFFFA000), // 10
    Color(0xFFFFC107), // 11
    Color(0xFFFFD740), // 12
    Color(0xFFFFEA00), // 13
    Color(0xFFFFFF00), // 14
    Color(0xFFFFF176), // 15
    // Verts
    Color(0xFFB2FF59), // 16
    Color(0xFF76FF03), // 17
    Color(0xFF64DD17), // 18
    Color(0xFF00E676), // 19
    Color(0xFF00C853), // 20
    Color(0xFF00FF00), // 21
    Color(0xFF69F0AE), // 22
    Color(0xFF00FFB0), // 23
    // Cyans / turquoises
    Color(0xFF00FFFF), // 24
    Color(0xFF18FFFF), // 25
    Color(0xFF00E5FF), // 26
    Color(0xFF00B8D4), // 27
    Color(0xFF00ACC1), // 28
    Color(0xFF26C6DA), // 29
    Color(0xFF4DD0E1), // 30
    Color(0xFF80DEEA), // 31
    // Bleus
    Color(0xFF40C4FF), // 32
    Color(0xFF00B0FF), // 33
    Color(0xFF0091EA), // 34
    Color(0xFF2196F3), // 35
    Color(0xFF1E88E5), // 36
    Color(0xFF1976D2), // 37
    Color(0xFF2962FF), // 38
    Color(0xFF0000FF), // 39
    // Violets
    Color(0xFF7C4DFF), // 40
    Color(0xFF651FFF), // 41
    Color(0xFF6200EA), // 42
    Color(0xFF7B1FA2), // 43
    Color(0xFF8E24AA), // 44
    Color(0xFF9C27B0), // 45
    Color(0xFFAA00FF), // 46
    Color(0xFF8800FF), // 47
    // Blancs / gris
    Color(0xFFFFFFFF), // 48
    Color(0xFFF5F5F5), // 49
    Color(0xFFEEEEEE), // 50
    Color(0xFFE0E0E0), // 51
    Color(0xFFBDBDBD), // 52
    Color(0xFF9E9E9E), // 53
    Color(0xFF757575), // 54
    Color(0xFF424242), // 55
    // Tons bonus
    Color(0xFFFFD700), // 56 - Gold
    Color(0xFFFFC0CB), // 57 - Pink clair
    Color(0xFFADFF2F), // 58 - GreenYellow
    Color(0xFF7FFFD4), // 59 - Aquamarine
    Color(0xFF87CEEB), // 60 - SkyBlue
    Color(0xFFBA55D3), // 61 - MediumOrchid
    Color(0xFFFF7F50), // 62 - Coral
    Color(0xFFA52A2A), // 63 - Brown
  ];

  static final List<int> textModeColors = [for (int i = 1; i < 64; i++) i];

  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color surfaceColor = Color(0xFFFDF5F5);
  static const Color borderColor = Color(0xFFEBD0D0);
  static const Color accentColor = Color(0xFF620505);
  static const Color secondaryAccent = Color(0xFF9B2020);
  static const Color dangerColor = Color(0xFFB33030);
  static const Color warningColor = Color(0xFFB36800);
  static const Color successColor = Color(0xFF2E6B2E);

  static const double defaultPadding = 12.0;
  static const double defaultRadius = 10.0;
  static const double smallRadius = 6.0;
}
