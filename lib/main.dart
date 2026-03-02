// ============================================================================
// 📁 main.dart
// ============================================================================
// Point d'entrée de l'application - MINIMAL !
// Toute la configuration est dans app.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';

void main() {
  // S'assurer que Flutter est initialisé
  WidgetsFlutterBinding.ensureInitialized();

  // Lancer l'application
  runApp(const LedMatrixApp());
}