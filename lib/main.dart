import 'package:flutter/material.dart';

import 'app.dart';
import 'services/storage_service.dart';
import 'services/sms_service.dart';
import 'dart:io';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();
  if (Platform.isAndroid) {
    await SmsService.requestPermission();
  }
  runApp(const LedMatrixApp());
}
