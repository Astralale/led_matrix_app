import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';

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
  static const String _keyEmergencyContacts = 'emergency_contacts';  // NOUVEAU

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ============================================================================
  // Paramètres existants
  // ============================================================================

  String get emergencyMessage =>
      _prefs.getString(_keyEmergencyMessage) ?? 'HELP';

  set emergencyMessage(String value) =>
      _prefs.setString(_keyEmergencyMessage, value);

  int get scrollSpeedMs => _prefs.getInt(_keyScrollSpeedMs) ?? 60;

  set scrollSpeedMs(int value) => _prefs.setInt(_keyScrollSpeedMs, value);

  int get blinkIntervalMs => _prefs.getInt(_keyBlinkIntervalMs) ?? 500;

  set blinkIntervalMs(int value) => _prefs.setInt(_keyBlinkIntervalMs, value);

  int get brightness => _prefs.getInt(_keyBrightness) ?? 60;

  set brightness(int value) => _prefs.setInt(_keyBrightness, value);

  int get selectedColorIndex => _prefs.getInt(_keySelectedColorIndex) ?? 1;

  set selectedColorIndex(int value) =>
      _prefs.setInt(_keySelectedColorIndex, value);

  String? get lastDeviceId => _prefs.getString(_keyLastDeviceId);

  set lastDeviceId(String? value) {
    if (value != null) {
      _prefs.setString(_keyLastDeviceId, value);
    } else {
      _prefs.remove(_keyLastDeviceId);
    }
  }

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

  // ============================================================================
  // NOUVEAU : Contacts d'urgence
  // ============================================================================

  List<EmergencyContact> get emergencyContacts {
    final json = _prefs.getString(_keyEmergencyContacts);
    if (json == null || json.isEmpty) return [];

    List<dynamic> jsonList = jsonDecode(json);
    return jsonList
        .map((item) => EmergencyContact.fromJson(item))
        .toList();
  }

  set emergencyContacts(List<EmergencyContact> contacts) {
    List<Map<String, dynamic>> jsonList = contacts
        .map((contact) => contact.toJson())
        .toList();
    _prefs.setString(_keyEmergencyContacts, jsonEncode(jsonList));
  }

  void addEmergencyContact(EmergencyContact contact) {
    final contacts = emergencyContacts;
    contacts.add(contact);
    emergencyContacts = contacts;
  }

  void removeEmergencyContact(String id) {
    final contacts = emergencyContacts;
    contacts.removeWhere((contact) => contact.id == id);
    emergencyContacts = contacts;
  }

  void updateEmergencyContact(EmergencyContact updated) {
    final contacts = emergencyContacts;
    final index = contacts.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      contacts[index] = updated;
      emergencyContacts = contacts;
    }
  }
}