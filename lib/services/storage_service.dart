// ============================================================================
// 📁 services/storage_service.dart
// ============================================================================
// Persistance des paramètres utilisateur via SharedPreferences.
// Singleton — accès via StorageService.instance
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const String _keyEmergencyMessage = 'emergency_message';
  static const String _keyScrollSpeedMs = 'scroll_speed_ms';
  static const String _keyBlinkIntervalMs = 'blink_interval_ms';
  static const String _keyBrightness = 'brightness';
  static const String _keySelectedColorIndex = 'selected_color_index';
  static const String _keyLastDeviceId = 'last_ble_device_id';
  static const String _keySavedDesigns = 'saved_designs';

  late SharedPreferences _prefs;

  /// Must be called once before using any getter/setter.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---------------------------------------------------------------------------
  // Message d'urgence
  // ---------------------------------------------------------------------------

  String get emergencyMessage =>
      _prefs.getString(_keyEmergencyMessage) ?? 'HELP';

  set emergencyMessage(String value) =>
      _prefs.setString(_keyEmergencyMessage, value);

  // ---------------------------------------------------------------------------
  // Vitesse de défilement (ms entre deux frames)
  // ---------------------------------------------------------------------------

  int get scrollSpeedMs => _prefs.getInt(_keyScrollSpeedMs) ?? 60;

  set scrollSpeedMs(int value) => _prefs.setInt(_keyScrollSpeedMs, value);

  // ---------------------------------------------------------------------------
  // Intervalle de clignotement (ms)
  // ---------------------------------------------------------------------------

  int get blinkIntervalMs => _prefs.getInt(_keyBlinkIntervalMs) ?? 500;

  set blinkIntervalMs(int value) => _prefs.setInt(_keyBlinkIntervalMs, value);

  // ---------------------------------------------------------------------------
  // Luminosité (0–255)
  // ---------------------------------------------------------------------------

  int get brightness => _prefs.getInt(_keyBrightness) ?? 60;

  set brightness(int value) => _prefs.setInt(_keyBrightness, value);

  // ---------------------------------------------------------------------------
  // Couleur sélectionnée (index dans la palette)
  // ---------------------------------------------------------------------------

  int get selectedColorIndex => _prefs.getInt(_keySelectedColorIndex) ?? 1;

  set selectedColorIndex(int value) =>
      _prefs.setInt(_keySelectedColorIndex, value);

  // ---------------------------------------------------------------------------
  // Dernier appareil BLE connecté (pour reconnexion rapide)
  // ---------------------------------------------------------------------------

  String? get lastDeviceId => _prefs.getString(_keyLastDeviceId);

  set lastDeviceId(String? value) {
    if (value != null) {
      _prefs.setString(_keyLastDeviceId, value);
    } else {
      _prefs.remove(_keyLastDeviceId);
    }
  }

  // ---------------------------------------------------------------------------
  // Dessins sauvegardés
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> get savedDesigns {
    final json = _prefs.getString(_keySavedDesigns);
    if (json == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(json) as List);
  }

  void saveDesign(String name, List<List<int>> pixels) {
    final designs = savedDesigns;
    designs.add({
      'name': name,
      'pixels': pixels,
      'date': DateTime.now().toIso8601String(),
    });
    _prefs.setString(_keySavedDesigns, jsonEncode(designs));
  }

  void deleteDesign(int index) {
    final designs = savedDesigns;
    if (index >= 0 && index < designs.length) {
      designs.removeAt(index);
      _prefs.setString(_keySavedDesigns, jsonEncode(designs));
    }
  }
}
