import 'package:geolocator/geolocator.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../config/SmtpConfig.dart';
import '../models/emergency_contact.dart';
import 'location_service.dart';
import 'storage_service.dart';

class MailResult {
  final bool success;
  final String message;

  MailResult({required this.success, required this.message});
}

class MailService {
  MailService._();

  static Future<MailResult> sendMailAlert() async {
    final storage = StorageService.instance;
    final List<EmergencyContact> contacts = storage.emergencyContacts;

    final recipients = contacts
        .map((c) => (c.mailAddress ?? '').trim())
        .where((m) => m.isNotEmpty)
        .toList();

    if (recipients.isEmpty) {
      return MailResult(
        success: false,
        message: "Aucun contact d'urgence avec email",
      );
    }

    final Position? position = await LocationService.getCurrentPosition();
    final String body = _buildEmergencyMessage(position);

    return _sendSmtpEmail(
      to: recipients,
      subject: '🚨 ALERTE URGENCE - StaySeen',
      body: body,
    );
  }

  static Future<MailResult> _sendSmtpEmail({
    required List<String> to,
    required String subject,
    required String body,
  }) async {
    // Gmail STARTTLS
    final smtpServer = SmtpServer(
      SmtpConfig.host,
      port: SmtpConfig.port,
      username: SmtpConfig.username,
      password: SmtpConfig.appPassword,
      ssl: false,
      allowInsecure: false,
    );

    final message = Message()
      ..from = Address(SmtpConfig.username, 'StaySeen')
      ..recipients.addAll(to)
      ..subject = subject
      ..text = body;

    try {
      await send(message, smtpServer);
      return MailResult(
        success: true,
        message: 'Email envoyé à ${to.length} contact(s)',
      );
    } catch (e) {
      return MailResult(success: false, message: "Échec d'envoi email: $e");
    }
  }

  static String _buildEmergencyMessage(Position? position) {
    final now = DateTime.now();
    final b = StringBuffer();

    b.writeln('🚨 URGENCE — StaySeen');
    b.writeln('⏱️ ${now.toLocal()}');
    b.writeln();
    b.writeln(
      "J'ai besoin d'aide. Merci d'essayer de me joindre immédiatement :",
    );
    b.writeln();

    if (position != null) {
      final lat = position.latitude.toStringAsFixed(6);
      final lon = position.longitude.toStringAsFixed(6);

      b.writeln('📍 Localisation GPS');
      b.writeln('• Latitude : $lat');
      b.writeln('• Longitude : $lon');

      b.writeln('• Précision : ~${position.accuracy.toStringAsFixed(0)} m');

      b.writeln();
      b.writeln('🗺️ Ouvrir la position :');

      final googleMaps = 'https://www.google.com/maps?q=$lat,$lon&z=17';
      b.writeln('• Google Maps : $googleMaps');

      final applePlans = 'http://maps.apple.com/?ll=$lat,$lon&q=$lat,$lon';
      b.writeln('• Apple Plans : $applePlans');

      final geo = 'geo:$lat,$lon?q=$lat,$lon';
      b.writeln('• Android (geo) : $geo');
    } else {
      b.writeln('📍 Position GPS non disponible.');
      b.writeln('➡️ Dernière option : essayer de me joindre par téléphone.');
    }

    b.writeln();
    b.writeln('— Message automatique StaySeen');

    return b.toString();
  }
}
