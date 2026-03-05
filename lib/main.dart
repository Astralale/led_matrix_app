import 'package:flutter/material.dart';
import 'dart:io';

import 'app.dart';
import 'services/storage_service.dart';
import 'services/sms_service.dart';
import 'services/ble_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.instance.init();

  if (Platform.isAndroid) {
    await SmsService.requestPermission();
  }

  BleService.instance.onAlertReceived = () async {
    print('ALERTE BOUTON ESP32 REÇUE !');

    final result = await SmsService.sendEmergencyAlert();

    if (result.success) {
      print('SMS envoyés: ${result.message}');
    } else {
      print('Erreur SMS: ${result.message}');
    }
  };

  runApp(const LedMatrixApp());
}