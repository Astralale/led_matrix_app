// ============================================================================
// 📁 main.dart
// ============================================================================
// Point d'entrée de l'application - MINIMAL !
// Toute la configuration est dans app.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'app.dart';
import 'services/storage_service.dart';

void main() async {
  // S'assurer que Flutter est initialisé
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser la persistance des paramètres
  await StorageService.instance.init();

  // Lancer l'application
  runApp(const LedMatrixApp());
}
