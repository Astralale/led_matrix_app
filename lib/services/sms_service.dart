// lib/services/sms_service.dart

import 'dart:io';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_contact.dart';
import 'location_service.dart';
import 'storage_service.dart';

class SmsResult {
  final bool success;
  final String message;

  SmsResult({required this.success, required this.message});
}

class SmsService {
  SmsService._();

  static final Telephony _telephony = Telephony.instance;

  /// Demande la permission SMS (à appeler au démarrage)
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;

    final bool? result = await _telephony.requestSmsPermissions;
    return result ?? false;
  }

  /// Envoie une alerte d'urgence à tous les contacts (SANS validation)
  static Future<SmsResult> sendEmergencyAlert() async {
    final storage = StorageService.instance;
    List<EmergencyContact> contacts = storage.emergencyContacts;

    if (contacts.isEmpty) {
      return SmsResult(
        success: false,
        message: 'Aucun contact d\'urgence enregistré',
      );
    }

    // Récupérer la position GPS
    Position? position = await LocationService.getCurrentPosition();

    // Construire le message
    String message = _buildEmergencyMessage(position);

    // Android : envoi direct
    if (Platform.isAndroid) {
      return await _sendDirectSms(contacts, message);
    }
    // iOS : fallback vers url_launcher (ouvre l'app SMS)
    else {
      return await _sendViaUrlLauncher(contacts, message);
    }
  }

  /// Envoi direct sur Android (SANS validation)
  static Future<SmsResult> _sendDirectSms(
      List<EmergencyContact> contacts,
      String message,
      ) async {
    int successCount = 0;
    int failCount = 0;

    for (final contact in contacts) {
      try {
        await _telephony.sendSms(
          to: contact.phoneNumber,
          message: message,
          isMultipart: true, // Pour les longs messages
        );
        successCount++;
        print('✅ SMS envoyé à ${contact.name} (${contact.phoneNumber})');
      } catch (e) {
        failCount++;
        print('❌ Échec envoi à ${contact.name}: $e');
      }
    }

    if (successCount > 0) {
      return SmsResult(
        success: true,
        message: 'SMS envoyé à $successCount contact(s)',
      );
    } else {
      return SmsResult(
        success: false,
        message: 'Échec d\'envoi à tous les contacts',
      );
    }
  }

  /// Fallback iOS (ouvre l'app SMS)
  static Future<SmsResult> _sendViaUrlLauncher(
      List<EmergencyContact> contacts,
      String message,
      ) async {
    String recipients = contacts.map((c) => c.phoneNumber).join(',');

    final uri = Uri(
      scheme: 'sms',
      path: recipients,
      queryParameters: {'body': message},
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return SmsResult(
          success: true,
          message: 'App SMS ouverte',
        );
      } else {
        return SmsResult(
          success: false,
          message: 'Impossible d\'ouvrir l\'app SMS',
        );
      }
    } catch (e) {
      return SmsResult(
        success: false,
        message: 'Erreur: $e',
      );
    }
  }

  /// Construit le message d'urgence
  static String _buildEmergencyMessage(Position? position) {
    final buffer = StringBuffer();

    buffer.write('🚨 ALERTE URGENCE 🚨\n\n');
    buffer.write('J\'ai besoin d\'aide !\n\n');

    if (position != null) {
      buffer.write('📍 Ma position:\n');
      buffer.write(LocationService.getGoogleMapsLink(position));
    } else {
      buffer.write('📍 Position GPS non disponible');
    }

    buffer.write('\n\nMessage envoyé via StaySeen');

    return buffer.toString();
  }

  /// Envoie un SMS de test (SANS validation)
  static Future<SmsResult> sendTestSms(String phoneNumber) async {
    Position? position = await LocationService.getCurrentPosition();

    final buffer = StringBuffer();
    buffer.write('🧪 TEST StaySeen\n\n');

    if (position != null) {
      buffer.write('📍 Position: ${LocationService.getGoogleMapsLink(position)}');
    } else {
      buffer.write('📍 GPS non disponible');
    }

    final message = buffer.toString();

    // Android : envoi direct
    if (Platform.isAndroid) {
      try {
        await _telephony.sendSms(
          to: phoneNumber,
          message: message,
          isMultipart: true,
        );
        return SmsResult(success: true, message: 'SMS de test envoyé !');
      } catch (e) {
        return SmsResult(success: false, message: 'Erreur: $e');
      }
    }
    // iOS : fallback
    else {
      final uri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return SmsResult(success: true, message: 'App SMS ouverte');
      } else {
        return SmsResult(success: false, message: 'Impossible d\'ouvrir l\'app SMS');
      }
    }
  }
}