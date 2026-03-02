import 'package:flutter/material.dart';

class AppConstants {

  AppConstants._();

  static const int matrixWidth = 40;
  static const int matrixHeight = 24;
  static const int totalLeds = matrixWidth * matrixHeight; // 960



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
  ];


  static const List<int> textModeColors = [1, 2, 3,4,5,6, 7, 8,9];


  static const Color backgroundColor = Color(0xFF0D1117);
  static const Color surfaceColor = Color(0xFF161B22);
  static const Color borderColor = Color(0xFF30363D);
  static const Color accentColor = Color(0xFF00FF88);
  static const Color secondaryAccent = Color(0xFF00CCFF);
  static const Color dangerColor = Color(0xFFFF4444);
  static const Color successColor = Color(0xFF238636);


  static const double defaultPadding = 12.0;
  static const double defaultRadius = 10.0;
  static const double smallRadius = 6.0;
}