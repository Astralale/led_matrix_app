// ============================================================================
// 📁 app.dart
// ============================================================================
// Configuration de l'application MaterialApp.
// Sépare la configuration du point d'entrée.
// ============================================================================

import 'package:flutter/material.dart';
import 'config/constants.dart';
import 'screens/text_mode_screen.dart';

class LedMatrixApp extends StatelessWidget {
  const LedMatrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Métadonnées
      title: 'LED Matrix Controller',
      debugShowCheckedModeBanner: false,

      // Thème
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.accentColor,
          brightness: Brightness.dark,
        ),

        // Personnalisation des composants
        scaffoldBackgroundColor: AppConstants.backgroundColor,

        appBarTheme: const AppBarTheme(
          backgroundColor: AppConstants.surfaceColor,
          elevation: 0,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            ),
          ),
        ),
      ),

      // Écran d'accueil
      home: const TextModeScreen(),
    );
  }
}
