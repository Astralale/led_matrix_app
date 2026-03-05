import 'dart:io';

import 'package:flutter/material.dart';
import 'package:led_matrix_app/services/mail_service.dart';

import 'app.dart';
import 'services/ble_service.dart';
import 'services/sms_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.instance.init();

  if (Platform.isAndroid) {
    await SmsService.requestPermission();
  }

  BleService.instance.onAlertReceived = () async {
    print('ALERTE BOUTON ESP32 REÇUE !');

    final resultMail = await MailService.sendMailAlert();

    if (resultMail.success) {
      print('Mail envoyés: ${resultMail.message}');
    } else {
      print('Erreur Mail: ${resultMail.message}');
    }

    if (Platform.isAndroid) {
      final resultSms = await SmsService.sendEmergencyAlert();
      if (resultSms.success) {
        print('SMS envoyés: ${resultSms.message}');
      } else {
        print('Erreur SMS: ${resultSms.message}');
      }
    }
  };

  runApp(const LedMatrixApp());
}
