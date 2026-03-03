import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const int matrixWidth = 32;
  static const int matrixHeight = 16;
  static const int totalLeds = matrixWidth * matrixHeight; // 512

  static const List<Color> colorPalette = [
    Color(0xFF000000), // 0 - Éteint
    Color(0xFFFF0000), // 1 - Rouge
    Color(0xFF00FF00), // 2 - Vert
    Color(0xFF0000FF), // 3 - Bleu
    Color(0xFFFFFF00), // 4 - Jaune
    Color(0xFFFF00FF), // 5 - Magenta
    Color(0xFF00FFFF), // 6 - Cyan
    Color(0xFFFFFFFF), // 7 - Blanc
    Color(0xFFFF8800), // 8 - Orange
    Color(0xFF8800FF), // 9 - Violet
    Color(0xFFFF1493), // 10 - Rose
    Color(0xFFFF4400), // 11 - Rouge-orange
    Color(0xFF80FF00), // 12 - Vert lime
    Color(0xFF00AAFF), // 13 - Bleu ciel
    Color(0xFFFFD700), // 14 - Or
    Color(0xFF00FFB0), // 15 - Turquoise
  ];

  static const List<int> textModeColors = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
  ];

  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color surfaceColor = Color(0xFFFDF5F5);
  static const Color borderColor = Color(0xFFEBD0D0);
  static const Color accentColor = Color(0xFF620505);
  static const Color secondaryAccent = Color(0xFF9B2020);
  static const Color dangerColor = Color(0xFFB33030);
  static const Color successColor = Color(0xFF2E6B2E);

  static const double defaultPadding = 12.0;
  static const double defaultRadius = 10.0;
  static const double smallRadius = 6.0;
}
