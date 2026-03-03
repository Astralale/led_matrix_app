// ============================================================================
// 📁 app.dart
// ============================================================================
// Configuration de l'application MaterialApp.
// Sépare la configuration du point d'entrée.
// ============================================================================

import 'package:flutter/material.dart';
import 'config/constants.dart';
import 'screens/text_mode_screen.dart';
import 'services/notification_service.dart';

class LedMatrixApp extends StatelessWidget {
  const LedMatrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Clé globale pour les notifications (SnackBar)
      scaffoldMessengerKey: NotificationService.messengerKey,

      // Métadonnées
      title: 'LED Matrix Controller',
      debugShowCheckedModeBanner: false,

      // Thème
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.accentColor,
          brightness: Brightness.light,
        ),

        // Personnalisation des composants
        scaffoldBackgroundColor: AppConstants.backgroundColor,

        appBarTheme: const AppBarTheme(
          backgroundColor: AppConstants.backgroundColor,
          foregroundColor: AppConstants.accentColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppConstants.surfaceColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            borderSide: const BorderSide(color: AppConstants.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            borderSide: const BorderSide(color: AppConstants.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            borderSide: const BorderSide(
              color: AppConstants.accentColor,
              width: 1.5,
            ),
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.accentColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppConstants.accentColor,
            side: const BorderSide(color: AppConstants.borderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
            ),
          ),
        ),

        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppConstants.accentColor;
            }
            return Colors.grey.shade400;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppConstants.accentColor.withOpacity(0.3);
            }
            return AppConstants.borderColor;
          }),
        ),
      ),

      // Écran d'accueil
      home: const TextModeScreen(),
    );
  }
}
